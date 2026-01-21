import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/services/cart_service.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/amount_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';

// Invoice Template Types
enum InvoiceTemplate {
  classic,    // Black & White Professional
  modern,     // Blue Accent Modern
  minimal,    // Clean Minimal
  colorful,   // Colorful Creative
}

// Template Colors - Classic (Black & White)
const Color _bwPrimary = Colors.black;
const Color _bwBg = Colors.white;
const Color _textMain = Colors.black;
const Color _textSub = Color(0xFF424242);
const Color _headerBg = Color(0xFFF5F5F5);

// Template Colors - Modern (Blue)
const Color _modernPrimary = Color(0xFF2F7CF6);
const Color _modernBg = Colors.white;
const Color _modernHeaderBg = Color(0xFFE3F2FD);

// Template Colors - Minimal (Gray)
const Color _minimalPrimary = Color(0xFF37474F);
const Color _minimalBg = Colors.white;
const Color _minimalAccent = Color(0xFF78909C);
const Color _minimalHeaderBg = Color(0xFFF5F5F5);

// Template Colors - Colorful (Multi-color)
const Color _colorfulPrimary = Color(0xFF6A1B9A);
const Color _colorfulBg = Colors.white;
const Color _colorfulAccent = Color(0xFFFF6F00);
const Color _colorfulHeaderBg = Color(0xFFF3E5F5);

class InvoicePage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final String businessName;
  final String businessLocation;
  final String businessPhone;
  final String? businessGSTIN;
  final String invoiceNumber;
  final DateTime dateTime;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double discount;
  final List<Map<String, dynamic>>? taxes;
  final double total;
  final String paymentMode;
  final double cashReceived;
  final String? customerName;
  final String? customerPhone;
  final String? customerGSTIN;
  final String? customNote;
  final String? deliveryAddress;
  final bool isQuotation;

  const InvoicePage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.businessName,
    required this.businessLocation,
    required this.businessPhone,
    this.businessGSTIN,
    required this.invoiceNumber,
    required this.dateTime,
    required this.items,
    required this.subtotal,
    required this.discount,
    this.taxes,
    required this.total,
    required this.paymentMode,
    required this.cashReceived,
    this.customerName,
    this.customerPhone,
    this.customerGSTIN,
    this.customNote,
    this.deliveryAddress,
    this.isQuotation = false,
  });

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _storeId;

  // Celebration animation
  late AnimationController _celebrationController;
  bool _showCelebration = true;
  final List<_Confetti> _confettiParticles = [];

  late String businessName;
  late String businessLocation;
  late String businessPhone;
  String? businessGSTIN;
  String? businessEmail;
  String? businessLogoUrl;
  String? businessLicenseNumber;

  // Header Info Settings
  String _receiptHeader = 'INVOICE';
  bool _showLogo = true;
  bool _showEmail = true;
  bool _showPhone = true;
  bool _showGST = true;
  bool _showLicenseNumber = false;
  bool _showLocation = true;

  // Item Table Settings
  bool _showCustomerDetails = true;
  bool _showMeasuringUnit = true;
  bool _showMRP = false;
  bool _showPaymentMode = true;
  bool _showTotalItems = true;
  bool _showTotalQty = false;
  bool _showSaveAmountMessage = true;

  // Invoice Footer Settings
  String _footerDescription = 'Thank you for your business!';
  String? _footerImageUrl;

  // Quotation Footer Settings
  String _quotationFooterDescription = 'Thank You';

  // Template selection
  InvoiceTemplate _selectedTemplate = InvoiceTemplate.classic;

  // Stream subscription for store data changes
  StreamSubscription<Map<String, dynamic>>? _storeDataSubscription;

  // Customer rating
  bool _ratingDialogShown = false;

  @override
  void initState() {
    super.initState();
    businessName = widget.businessName;
    businessLocation = widget.businessLocation;
    businessPhone = widget.businessPhone;
    businessGSTIN = widget.businessGSTIN;
    _loadStoreData();
    _loadReceiptSettings();
    _loadTemplatePreference();

    // Initialize celebration animation
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Generate confetti particles
    _generateConfetti();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CartService>().clearCart();
        // Start celebration effects
        _startCelebration();
        // Check if we should show rating dialog for first-time customer
        _checkAndShowRatingDialog();
      }
    });

    _storeDataSubscription = FirestoreService().storeDataStream.listen((storeData) {
      if (mounted) {
        setState(() {
          businessLogoUrl = storeData['logoUrl'];
          businessName = storeData['businessName'] ?? businessName;
          businessPhone = storeData['businessPhone'] ?? businessPhone;
          businessLocation = storeData['businessLocation'] ?? businessLocation;
          businessGSTIN = storeData['gstin'];
          // Email can be stored as 'email' or 'ownerEmail'
          businessEmail = storeData['email'] ?? storeData['ownerEmail'];
          businessLicenseNumber = storeData['licenseNumber'];
        });
        debugPrint('Invoice: Store data updated via stream - logo=$businessLogoUrl, email=$businessEmail, gstin=$businessGSTIN');
      }
    });
  }

  @override
  void dispose() {
    _storeDataSubscription?.cancel();
    _celebrationController.dispose();
    super.dispose();
  }

  /// Check if this is the customer's first purchase and show rating dialog
  Future<void> _checkAndShowRatingDialog() async {
    // Only show for customers with phone number (identified customers)
    if (widget.customerPhone == null || widget.customerPhone!.isEmpty) {
      debugPrint('❌ Rating dialog: No customer phone');
      return;
    }
    if (_ratingDialogShown) {
      debugPrint('❌ Rating dialog: Already shown');
      return;
    }

    try {
      // Add a delay to ensure purchaseCount has been updated
      await Future.delayed(const Duration(milliseconds: 1000));

      final customersCollection = await FirestoreService().getStoreCollection('customers');
      final customerDoc = await customersCollection.doc(widget.customerPhone).get();

      debugPrint('📊 Checking rating for customer: ${widget.customerPhone}');

      if (customerDoc.exists) {
        final data = customerDoc.data() as Map<String, dynamic>?;
        final purchaseCount = data?['purchaseCount'] ?? 0;
        final hasRating = data?['rating'] != null;

        debugPrint('   Purchase Count: $purchaseCount');
        debugPrint('   Has Rating: $hasRating');

        // Show rating dialog for first-time purchase (purchaseCount 0 or 1) and no existing rating
        // Note: purchaseCount may be 0 if sale hasn't synced yet, or 1 if sync completed
        if (purchaseCount <= 1 && !hasRating) {
          debugPrint('✅ Showing rating dialog for first-time customer');
          // Wait for celebration to finish before showing rating dialog
          await Future.delayed(const Duration(milliseconds: 2500));
          if (mounted && !_ratingDialogShown) {
            _ratingDialogShown = true;
            _showRatingDialog();
          }
        } else {
          debugPrint('❌ Rating dialog: purchaseCount=$purchaseCount, hasRating=$hasRating');
        }
      } else {
        debugPrint('❌ Rating dialog: Customer document does not exist - might be new customer');
        // For brand new customers that don't have a document yet, show rating dialog
        debugPrint('✅ Showing rating dialog for brand new customer');
        await Future.delayed(const Duration(milliseconds: 2500));
        if (mounted && !_ratingDialogShown) {
          _ratingDialogShown = true;
          _showRatingDialog();
        }
      }
    } catch (e) {
      debugPrint('Error checking customer rating: $e');
    }
  }

  /// Show the 5-star rating dialog
  void _showRatingDialog() {
    int selectedRating = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Customer avatar
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (widget.customerName ?? 'C')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'Rate this Customer',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: kBlack87,
                  ),
                ),
                const SizedBox(height: 8),

                // Customer name
                Text(
                  widget.customerName ?? 'Customer',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kBlack54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.customerPhone ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: kBlack54,
                  ),
                ),
                const SizedBox(height: 24),

                // 5-star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedRating = index + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 40,
                          color: index < selectedRating ? kOrange : kGrey300,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // Rating text
                Text(
                  selectedRating == 0
                      ? 'Tap to rate'
                      : selectedRating == 1
                      ? 'Poor'
                      : selectedRating == 2
                      ? 'Fair'
                      : selectedRating == 3
                      ? 'Good'
                      : selectedRating == 4
                      ? 'Very Good'
                      : 'Excellent!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selectedRating > 0 ? kPrimaryColor : kBlack54,
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    // Skip button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: kGrey300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'SKIP',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: kBlack54,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Submit button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedRating > 0
                            ? () {
                          _submitCustomerRating(selectedRating);
                          Navigator.pop(context);
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          disabledBackgroundColor: kGrey200,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'SUBMIT',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Submit customer rating to Firestore
  Future<void> _submitCustomerRating(int rating) async {
    if (widget.customerPhone == null || widget.customerPhone!.isEmpty) return;

    try {
      final customersCollection = await FirestoreService().getStoreCollection('customers');
      await customersCollection.doc(widget.customerPhone).set({
        'rating': rating,
        'ratedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star_rounded, color: kOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Customer rated $rating star${rating > 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: kGoogleGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting customer rating: $e');
    }
  }

  void _generateConfetti() {
    final random = Random();
    for (int i = 0; i < 50; i++) {
      _confettiParticles.add(_Confetti(
        x: random.nextDouble(),
        y: random.nextDouble() * -1, // Start above screen
        color: [kPrimaryColor, kOrange, kGoogleGreen, Colors.purple, Colors.pink, Colors.amber][random.nextInt(6)],
        size: random.nextDouble() * 8 + 4,
        speed: random.nextDouble() * 0.5 + 0.3,
        rotation: random.nextDouble() * 360,
      ));
    }
  }

  Future<void> _startCelebration() async {
    // Vibration feedback - short burst pattern
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 300));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 300));
    await HapticFeedback.heavyImpact();

    // Play success sound using system sound
    await SystemSound.play(SystemSoundType.click);

    // Start confetti animation
    _celebrationController.forward();

    // Hide celebration after animation completes
    await Future.delayed(const Duration(milliseconds: 3000));
    if (mounted) {
      setState(() => _showCelebration = false);
    }
  }

  Future<void> _loadTemplatePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templateIndex = prefs.getInt('invoice_template') ?? 0;
      setState(() {
        _selectedTemplate = InvoiceTemplate.values[templateIndex];
      });
    } catch (e) {
      debugPrint('Error loading template preference: $e');
    }
  }

  Future<void> _loadReceiptSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        // Header Info
        _receiptHeader = prefs.getString('receipt_header') ?? 'INVOICE';
        _showLogo = prefs.getBool('receipt_show_logo') ?? true;
        _showEmail = prefs.getBool('receipt_show_email') ?? true;
        _showPhone = prefs.getBool('receipt_show_phone') ?? true;
        _showGST = prefs.getBool('receipt_show_gst') ?? true;
        _showLicenseNumber = prefs.getBool('receipt_show_license') ?? false;
        _showLocation = prefs.getBool('receipt_show_location') ?? true;

        // Item Table
        _showCustomerDetails = prefs.getBool('receipt_show_customer_details') ?? true;
        _showMeasuringUnit = prefs.getBool('receipt_show_measuring_unit') ?? true;
        _showMRP = prefs.getBool('receipt_show_mrp') ?? false;
        _showPaymentMode = prefs.getBool('receipt_show_payment_mode') ?? true;
        _showTotalItems = prefs.getBool('receipt_show_total_items') ?? true;
        _showTotalQty = prefs.getBool('receipt_show_total_qty') ?? false;
        _showSaveAmountMessage = prefs.getBool('receipt_show_save_amount') ?? true;

        // Invoice Footer
        _footerDescription = prefs.getString('receipt_footer_description') ?? 'Thank you for your business!';
        _footerImageUrl = prefs.getString('receipt_footer_image');

        // Quotation Footer
        _quotationFooterDescription = prefs.getString('quotation_footer_description') ?? 'Thank You';
      });
    } catch (e) {
      debugPrint('Error loading receipt settings: $e');
    }
  }

  Future<void> _loadStoreData() async {
    try {
      // Use the same method as Profile.dart - FirestoreService().getCurrentStoreDoc()
      final store = await FirestoreService().getCurrentStoreDoc();
      if (store != null && store.exists) {
        final data = store.data() as Map<String, dynamic>;
        _storeId = store.id;
        setState(() {
          businessName = data['businessName'] ?? widget.businessName;
          businessPhone = data['businessPhone'] ?? widget.businessPhone;
          businessLocation = data['businessLocation'] ?? widget.businessLocation;
          businessGSTIN = data['gstin'] ?? widget.businessGSTIN;
          // Email can be stored as 'email' or 'ownerEmail'
          businessEmail = data['email'] ?? data['ownerEmail'];
          businessLogoUrl = data['logoUrl'];
          businessLicenseNumber = data['licenseNumber'];
          _isLoading = false;
        });
        debugPrint('Invoice: Store data loaded - name=$businessName, logo=$businessLogoUrl, email=$businessEmail, gstin=$businessGSTIN, license=$businessLicenseNumber, location=$businessLocation');
        return;
      }
      setState(() { _isLoading = false; });
    } catch (e) {
      debugPrint('Error loading store data: $e');
      setState(() { _isLoading = false; });
    }
  }


  @override
  Widget build(BuildContext context) {
    final templateColors = _getTemplateColors(_selectedTemplate);

    return Scaffold(
      backgroundColor: templateColors['bg'],
      appBar: AppBar(
        backgroundColor: templateColors['bg'],
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isQuotation
              ? 'QUOTATION DETAILS'
              : context.tr('invoice details').toUpperCase(),
          style: TextStyle(
            color: templateColors['primary'],
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.0,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: templateColors['primary']),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            CupertinoPageRoute(builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.userEmail)),
                (route) => false,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: templateColors['primary']),
            onPressed: _showInvoiceSettings,
          )
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator(color: templateColors['primary']))
              : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            child: _buildInvoiceByTemplate(_selectedTemplate, templateColors),
          ),
          // Celebration confetti overlay
          if (_showCelebration)
            AnimatedBuilder(
              animation: _celebrationController,
              builder: (context, child) {
                return IgnorePointer(
                  child: CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _ConfettiPainter(
                      particles: _confettiParticles,
                      progress: _celebrationController.value,
                    ),
                  ),
                );
              },
            ),
          // Success checkmark animation in center
          if (_showCelebration)
            AnimatedBuilder(
              animation: _celebrationController,
              builder: (context, child) {
                // Scale animation: grow from 0 to 1 in first 30% of animation
                final scaleProgress = (_celebrationController.value / 0.3).clamp(0.0, 1.0);
                final scale = Curves.elasticOut.transform(scaleProgress);

                // Fade out in last 20% of animation
                final fadeProgress = ((_celebrationController.value - 0.8) / 0.2).clamp(0.0, 1.0);
                final opacity = 1.0 - fadeProgress;

                return IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: kGoogleGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: kGoogleGreen.withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 70,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Map<String, Color> _getTemplateColors(InvoiceTemplate template) {
    switch (template) {
      case InvoiceTemplate.classic:
        return {
          'primary': _bwPrimary,
          'bg': _bwBg,
          'text': _textMain,
          'textSub': _textSub,
          'headerBg': _headerBg,
        };
      case InvoiceTemplate.modern:
        return {
          'primary': _modernPrimary,
          'bg': _modernBg,
          'text': _modernPrimary,
          'textSub': kBlack54,
          'headerBg': _modernHeaderBg,
        };
      case InvoiceTemplate.minimal:
        return {
          'primary': _minimalPrimary,
          'bg': _minimalBg,
          'text': _minimalPrimary,
          'textSub': _minimalAccent,
          'headerBg': _minimalHeaderBg,
        };
      case InvoiceTemplate.colorful:
        return {
          'primary': _colorfulPrimary,
          'bg': _colorfulBg,
          'text': _colorfulPrimary,
          'textSub': _colorfulAccent,
          'headerBg': _colorfulHeaderBg,
        };
    }
  }

  void _showInvoiceSettings() {
    // Local state for expandable sections
    bool headerExpanded = true;
    bool itemTableExpanded = false;
    bool footerExpanded = false;

    // Text controllers for editable fields
    final headerCtrl = TextEditingController(text: _receiptHeader);
    final footerCtrl = TextEditingController(text: _footerDescription);
    final quotationFooterCtrl = TextEditingController(text: _quotationFooterDescription);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _getTemplateColors(_selectedTemplate)['primary'],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'RECEIPT CUSTOMIZATION',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Template Selection Section
                      _buildSectionLabel("TEMPLATE STYLE"),
                      ..._buildTemplateOptions(setModalState),
                      const SizedBox(height: 20),

                      // Header Info Section (Expandable)
                      _buildExpandableSection(
                        title: "Header Info",
                        isExpanded: headerExpanded,
                        onTap: () => setModalState(() => headerExpanded = !headerExpanded),
                        setModalState: setModalState,
                        children: [
                          _buildTextFieldInModal(headerCtrl, "Receipt Header", (v) {
                            setState(() => _receiptHeader = v);
                          }),
                          const SizedBox(height: 12),
                          _buildSettingTile('Company Logo', _showLogo, (v) {
                            setState(() => _showLogo = v);
                            setModalState(() => _showLogo = v);
                          }),
                          _buildSettingTile('Location', _showLocation, (v) {
                            setState(() => _showLocation = v);
                            setModalState(() => _showLocation = v);
                          }),
                          _buildSettingTile('Email', _showEmail, (v) {
                            setState(() => _showEmail = v);
                            setModalState(() => _showEmail = v);
                          }),
                          _buildSettingTile('Phone Number', _showPhone, (v) {
                            setState(() => _showPhone = v);
                            setModalState(() => _showPhone = v);
                          }),
                          _buildSettingTile('GST Number', _showGST, (v) {
                            setState(() => _showGST = v);
                            setModalState(() => _showGST = v);
                          }),
                          _buildSettingTile('License Number', _showLicenseNumber, (v) {
                            setState(() => _showLicenseNumber = v);
                            setModalState(() => _showLicenseNumber = v);
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Item Table Section (Expandable)
                      _buildExpandableSection(
                        title: "Item Table",
                        isExpanded: itemTableExpanded,
                        onTap: () => setModalState(() => itemTableExpanded = !itemTableExpanded),
                        setModalState: setModalState,
                        children: [
                          _buildSettingTile('Customer Details', _showCustomerDetails, (v) {
                            setState(() => _showCustomerDetails = v);
                            setModalState(() => _showCustomerDetails = v);
                          }),
                          _buildSettingTile('Measuring Unit', _showMeasuringUnit, (v) {
                            setState(() => _showMeasuringUnit = v);
                            setModalState(() => _showMeasuringUnit = v);
                          }),
                          _buildSettingTile('MRP', _showMRP, (v) {
                            setState(() => _showMRP = v);
                            setModalState(() => _showMRP = v);
                          }),
                          _buildSettingTile('Payment Mode', _showPaymentMode, (v) {
                            setState(() => _showPaymentMode = v);
                            setModalState(() => _showPaymentMode = v);
                          }),
                          _buildSettingTile('Total Items', _showTotalItems, (v) {
                            setState(() => _showTotalItems = v);
                            setModalState(() => _showTotalItems = v);
                          }),
                          _buildSettingTile('Total Qty', _showTotalQty, (v) {
                            setState(() => _showTotalQty = v);
                            setModalState(() => _showTotalQty = v);
                          }),
                          _buildSettingTile('Customer Save Amount', _showSaveAmountMessage, (v) {
                            setState(() => _showSaveAmountMessage = v);
                            setModalState(() => _showSaveAmountMessage = v);
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Footer Section (Expandable)
                      _buildExpandableSection(
                        title: "Invoice Footer",
                        isExpanded: footerExpanded,
                        onTap: () => setModalState(() => footerExpanded = !footerExpanded),
                        setModalState: setModalState,
                        children: [
                          const Text("Footer Description:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kBlack87)),
                          const SizedBox(height: 8),
                          _buildMultilineTextFieldInModal(footerCtrl, "Thank you for your business!", (v) {
                            setState(() => _footerDescription = v);
                          }),
                          const SizedBox(height: 16),
                          const Text("Quotation Footer:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kBlack87)),
                          const SizedBox(height: 8),
                          _buildMultilineTextFieldInModal(quotationFooterCtrl, "Thank You", (v) {
                            setState(() => _quotationFooterDescription = v);
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Update text values from controllers
                            _receiptHeader = headerCtrl.text;
                            _footerDescription = footerCtrl.text;
                            _quotationFooterDescription = quotationFooterCtrl.text;
                            await _saveInvoiceSettings();
                            if (mounted) {
                              Navigator.pop(context);
                              setState(() {}); // Refresh the invoice view
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getTemplateColors(_selectedTemplate)['primary'],
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Save preferences', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required StateSetter setModalState,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kBlack87)),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: _getTemplateColors(_selectedTemplate)['primary'],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: kGrey200),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextFieldInModal(TextEditingController controller, String label, Function(String) onChanged) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kBlack54, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: kGreyBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kGrey200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _getTemplateColors(_selectedTemplate)['primary']!, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildMultilineTextFieldInModal(TextEditingController controller, String hint, Function(String) onChanged) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: 3,
      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kGrey400, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: kGreyBg,
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kGrey200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _getTemplateColors(_selectedTemplate)['primary']!, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0)));

  List<Widget> _buildTemplateOptions(StateSetter setModalState) {
    final templates = [
      {'index': 0, 'title': 'Classic Professional', 'icon': Icons.article_rounded, 'color': Colors.black},
      {'index': 1, 'title': 'Modern Business', 'icon': Icons.receipt_long_rounded, 'color': const Color(0xFF2F7CF6)},
      {'index': 2, 'title': 'Compact Receipt', 'icon': Icons.description_rounded, 'color': const Color(0xFF37474F)},
      {'index': 3, 'title': 'Detailed Creative', 'icon': Icons.summarize_rounded, 'color': const Color(0xFF6A1B9A)},
    ];

    return templates.map((template) {
      final isSelected = _selectedTemplate.index == template['index'];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () {
            setState(() => _selectedTemplate = InvoiceTemplate.values[template['index'] as int]);
            setModalState(() => _selectedTemplate = InvoiceTemplate.values[template['index'] as int]);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kWhite,
              border: Border.all(
                color: isSelected ? template['color'] as Color : kGrey200,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(template['icon'] as IconData, color: isSelected ? template['color'] as Color : kBlack54, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    template['title'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? template['color'] as Color : kBlack87,
                    ),
                  ),
                ),
                if (isSelected) Icon(Icons.check_circle_rounded, color: template['color'] as Color, size: 20),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSettingTile(String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGrey200),
      ),
      child: SwitchListTile.adaptive(
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87)),
        value: value,
        onChanged: onChanged,
        activeColor: _getTemplateColors(_selectedTemplate)['primary'],
      ),
    );
  }

  Future<void> _saveInvoiceSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Template
      await prefs.setInt('invoice_template', _selectedTemplate.index);

      // Header Info
      await prefs.setString('receipt_header', _receiptHeader);
      await prefs.setBool('receipt_show_logo', _showLogo);
      await prefs.setBool('receipt_show_email', _showEmail);
      await prefs.setBool('receipt_show_phone', _showPhone);
      await prefs.setBool('receipt_show_gst', _showGST);
      await prefs.setBool('receipt_show_license', _showLicenseNumber);
      await prefs.setBool('receipt_show_location', _showLocation);

      // Item Table Settings
      await prefs.setBool('receipt_show_customer_details', _showCustomerDetails);
      await prefs.setBool('receipt_show_measuring_unit', _showMeasuringUnit);
      await prefs.setBool('receipt_show_mrp', _showMRP);
      await prefs.setBool('receipt_show_payment_mode', _showPaymentMode);
      await prefs.setBool('receipt_show_total_items', _showTotalItems);
      await prefs.setBool('receipt_show_total_qty', _showTotalQty);
      await prefs.setBool('receipt_show_save_amount', _showSaveAmountMessage);

      // Footer Settings
      await prefs.setString('receipt_footer_description', _footerDescription);
      await prefs.setString('quotation_footer_description', _quotationFooterDescription);
      if (_footerImageUrl != null) {
        await prefs.setString('receipt_footer_image', _footerImageUrl!);
      }

      // Also save to Firestore for sync across devices
      try {
        final storeId = await FirestoreService().getCurrentStoreId();
        if (storeId != null) {
          await FirebaseFirestore.instance.collection('store').doc(storeId).update({
            'invoiceSettings': {
              'template': _selectedTemplate.index,
              'header': _receiptHeader,
              'showLogo': _showLogo,
              'showEmail': _showEmail,
              'showPhone': _showPhone,
              'showGST': _showGST,
              'showLicense': _showLicenseNumber,
              'showLocation': _showLocation,
              'showCustomerDetails': _showCustomerDetails,
              'showMeasuringUnit': _showMeasuringUnit,
              'showMRP': _showMRP,
              'showPaymentMode': _showPaymentMode,
              'showTotalItems': _showTotalItems,
              'showTotalQty': _showTotalQty,
              'showSaveAmount': _showSaveAmountMessage,
              'footerDescription': _footerDescription,
              'footerImageUrl': _footerImageUrl,
              'quotationFooter': _quotationFooterDescription,
            }
          });
        }
      } catch (e) {
        debugPrint('Error saving to Firestore: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt settings updated'), backgroundColor: kGoogleGreen, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Widget _buildInvoiceByTemplate(InvoiceTemplate template, Map<String, Color> colors) {
    switch (template) {
      case InvoiceTemplate.classic:
        return _buildClassicLayout(colors);
      case InvoiceTemplate.modern:
        return _buildModernLayout(colors);
      case InvoiceTemplate.minimal:
        return _buildCompactLayout(colors);
      case InvoiceTemplate.colorful:
        return _buildDetailedLayout(colors);
    }
  }

  // Template 1: Classic Professional Layout
  Widget _buildClassicLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors['primary']!, width: 1.5),
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors['primary']!, width: 1.5)),
            ),
            child: Column(
              children: [
                // Logo - show placeholder if toggle ON but no logo
                if (_showLogo)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: businessLogoUrl != null && businessLogoUrl!.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        businessLogoUrl!,
                        height: 64,
                        width: 64,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 64,
                            width: 64,
                            decoration: BoxDecoration(
                              color: colors['headerBg'],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 64,
                          width: 64,
                          decoration: BoxDecoration(
                            color: colors['headerBg'],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.store_rounded, size: 32, color: colors['textSub']),
                        ),
                      ),
                    )
                        : Container(
                      height: 64,
                      width: 64,
                      decoration: BoxDecoration(
                        color: colors['headerBg'],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kGrey200),
                      ),
                      child: Icon(Icons.add_photo_alternate_outlined, size: 28, color: colors['textSub']),
                    ),
                  ),
                // Business Name
                Text(
                  businessName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: colors['primary'], letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                // Location
                if (_showLocation && businessLocation.isNotEmpty)
                  Text(businessLocation, textAlign: TextAlign.center, style: TextStyle(color: colors['textSub'], fontSize: 11, fontWeight: FontWeight.w500)),
                // Phone
                if (_showPhone && businessPhone.isNotEmpty)
                  Text("Tel: $businessPhone", textAlign: TextAlign.center, style: TextStyle(color: colors['textSub'], fontSize: 11, fontWeight: FontWeight.w500)),
                // Email - show if toggle ON (with or without data)
                if (_showEmail)
                  Text(
                    businessEmail != null && businessEmail!.isNotEmpty
                        ? "Email: $businessEmail"
                        : "Email: Not set",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: businessEmail != null && businessEmail!.isNotEmpty ? colors['textSub'] : kGrey400,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontStyle: businessEmail != null && businessEmail!.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                // GST/Tax Number - show if toggle ON (with or without data)
                if (_showGST)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      businessGSTIN != null && businessGSTIN!.isNotEmpty
                          ? "TAX NO : $businessGSTIN"
                          : "TAX NO : Not set",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: businessGSTIN != null && businessGSTIN!.isNotEmpty ? colors['primary'] : kGrey400,
                        fontSize: 11,
                        fontWeight: businessGSTIN != null && businessGSTIN!.isNotEmpty ? FontWeight.w900 : FontWeight.w500,
                        fontStyle: businessGSTIN != null && businessGSTIN!.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ),
                // License Number - show if toggle ON (with or without data)
                if (_showLicenseNumber)
                  Text(
                    businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty
                        ? "License: $businessLicenseNumber"
                        : "License: Not set",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty ? colors['textSub'] : kGrey400,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontStyle: businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          _buildStandardBody(colors),
        ],
      ),
    );
  }

  Widget _buildStandardBody(Map<String, Color> colors) {
    // Use custom header or default
    final headerText = widget.isQuotation ? 'QUOTATION' : _receiptHeader;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$headerText #${widget.invoiceNumber}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: colors['text'])),
              Text(DateFormat('dd MMM yyyy').format(widget.dateTime), style: TextStyle(fontSize: 11, color: colors['textSub'], fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        // Customer Details - controlled by _showCustomerDetails
        if (_showCustomerDetails && widget.customerName != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors['headerBg'],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Bill To: ${widget.customerName}", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: colors['text'])),
                    if (widget.customerPhone != null) Text(widget.customerPhone!, style: TextStyle(color: colors['textSub'], fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                // Customer GSTIN if available
                if (widget.customerGSTIN != null && widget.customerGSTIN!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text("GSTIN: ${widget.customerGSTIN}", style: TextStyle(color: colors['textSub'], fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _buildTableHeader(colors),
        _buildItemsList(colors),
        _buildSummary(colors),
        // Footer with customizable description
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: colors['headerBg'],
            border: Border(top: BorderSide(color: colors['primary']!, width: 1)),
          ),
          child: Column(
            children: [
              Text(
                widget.isQuotation ? _quotationFooterDescription.toUpperCase() : _footerDescription.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors['text'], fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0),
              ),
              // Footer Image if available (show for both invoice and quotation)
              if (_footerImageUrl != null && _footerImageUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Image.network(
                    _footerImageUrl!,
                    height: 50,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }


  // Template 2: Modern Business Layout
  Widget _buildModernLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: kGrey200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors['primary'],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(businessName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          if (_showLocation && businessLocation.isNotEmpty)
                            Text(businessLocation, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          if (_showPhone && businessPhone.isNotEmpty)
                            Text("Tel: $businessPhone", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          if (_showEmail)
                            Text(
                              businessEmail != null && businessEmail!.isNotEmpty ? "Email: $businessEmail" : "Email: Not set",
                              style: TextStyle(color: businessEmail != null && businessEmail!.isNotEmpty ? Colors.white70 : Colors.white38, fontSize: 11, fontStyle: businessEmail != null && businessEmail!.isNotEmpty ? FontStyle.normal : FontStyle.italic),
                            ),
                          if (_showGST)
                            Text(
                              businessGSTIN != null && businessGSTIN!.isNotEmpty ? "GSTIN: $businessGSTIN" : "GSTIN: Not set",
                              style: TextStyle(color: businessGSTIN != null && businessGSTIN!.isNotEmpty ? Colors.white : Colors.white38, fontSize: 11, fontWeight: businessGSTIN != null && businessGSTIN!.isNotEmpty ? FontWeight.w900 : FontWeight.w500, fontStyle: businessGSTIN != null && businessGSTIN!.isNotEmpty ? FontStyle.normal : FontStyle.italic),
                            ),
                          if (_showLicenseNumber)
                            Text(
                              businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty ? "License: $businessLicenseNumber" : "License: Not set",
                              style: TextStyle(color: businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty ? Colors.white70 : Colors.white38, fontSize: 11, fontStyle: businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty ? FontStyle.normal : FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                    if (_showLogo)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: businessLogoUrl != null && businessLogoUrl!.isNotEmpty
                            ? Image.network(
                          businessLogoUrl!,
                          height: 48,
                          width: 48,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.store_rounded, size: 32, color: colors['primary']),
                        )
                            : Icon(Icons.add_photo_alternate_outlined, size: 32, color: colors['primary']),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.isQuotation ? "REF QUOTATION" : _receiptHeader.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900)),
                          Text("#${widget.invoiceNumber}", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("DATE", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900)),
                          Text(DateFormat('dd MMM yyyy').format(widget.dateTime), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                if (_showCustomerDetails && widget.customerName != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: colors['headerBg'], borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Icon(Icons.person_rounded, color: colors['primary'], size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("BILL TO", style: TextStyle(color: kBlack54, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                Text(widget.customerName!, style: const TextStyle(color: kBlack87, fontSize: 14, fontWeight: FontWeight.w800)),
                                if (widget.customerPhone != null) Text(widget.customerPhone!, style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _buildTableHeader(colors),
                _buildItemsList(colors),
                _buildSummary(colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Template 3: Compact Layout
  Widget _buildCompactLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: kGrey300), color: Colors.white),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: colors['headerBg'],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(businessName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: colors['text'])),
                    if (_showLocation && businessLocation.isNotEmpty)
                      Text(businessLocation, style: TextStyle(fontSize: 9, color: colors['textSub'], fontWeight: FontWeight.w500)),
                    if (_showPhone && businessPhone.isNotEmpty)
                      Text("T: $businessPhone", style: TextStyle(fontSize: 9, color: colors['textSub'], fontWeight: FontWeight.w500)),
                    if (_showEmail)
                      Text(
                        businessEmail != null && businessEmail!.isNotEmpty ? "E: $businessEmail" : "E: Not set",
                        style: TextStyle(fontSize: 9, color: businessEmail != null && businessEmail!.isNotEmpty ? colors['textSub'] : kGrey400, fontWeight: FontWeight.w500, fontStyle: businessEmail != null && businessEmail!.isNotEmpty ? FontStyle.normal : FontStyle.italic),
                      ),
                    if (_showGST)
                      Text(
                        businessGSTIN != null && businessGSTIN!.isNotEmpty ? "GSTIN: $businessGSTIN" : "GSTIN: Not set",
                        style: TextStyle(fontSize: 9, color: businessGSTIN != null && businessGSTIN!.isNotEmpty ? colors['text'] : kGrey400, fontWeight: businessGSTIN != null && businessGSTIN!.isNotEmpty ? FontWeight.w900 : FontWeight.w500, fontStyle: businessGSTIN != null && businessGSTIN!.isNotEmpty ? FontStyle.normal : FontStyle.italic),
                      ),
                    if (_showLicenseNumber)
                      Text(
                        businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty ? "License: $businessLicenseNumber" : "License: Not set",
                        style: TextStyle(fontSize: 9, color: businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty ? colors['textSub'] : kGrey400, fontWeight: FontWeight.w500, fontStyle: businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty ? FontStyle.normal : FontStyle.italic),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("#${widget.invoiceNumber}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: colors['primary'])),
                    Text(DateFormat('dd MMM yyyy').format(widget.dateTime), style: TextStyle(fontSize: 10, color: colors['textSub'], fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                if (_showCustomerDetails && widget.customerName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                    child: Row(
                      children: [
                        const Text("TO: ", style: TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w800)),
                        Text(widget.customerName!, style: TextStyle(color: colors['text'], fontSize: 10, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                _buildTableHeader(colors),
                _buildItemsList(colors),
                _buildSummary(colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Template 4: Detailed Statement Layout
  Widget _buildDetailedLayout(Map<String, Color> colors) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: colors['primary']!, width: 2), color: Colors.white),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: colors['primary']),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_showLogo && businessLogoUrl != null && businessLogoUrl!.isNotEmpty)
                      Image.network(
                        businessLogoUrl!,
                        height: 44,
                        width: 44,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.store_rounded, size: 32, color: Colors.white70),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(widget.isQuotation ? "QUOTATION" : _receiptHeader.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        Text("#${widget.invoiceNumber}", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("FROM", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(businessName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                          if (_showLocation && businessLocation.isNotEmpty)
                            Text(businessLocation, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          if (_showPhone && businessPhone.isNotEmpty)
                            Text("Tel: $businessPhone", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          if (_showEmail)
                            Text(
                              businessEmail != null && businessEmail!.isNotEmpty ? "Email: $businessEmail" : "Email: Not set",
                              style: TextStyle(color: businessEmail != null && businessEmail!.isNotEmpty ? Colors.white70 : Colors.white38, fontSize: 10, fontStyle: businessEmail != null && businessEmail!.isNotEmpty ? FontStyle.normal : FontStyle.italic),
                            ),
                          if (_showGST)
                            Text(
                              businessGSTIN != null && businessGSTIN!.isNotEmpty ? "GSTIN: $businessGSTIN" : "GSTIN: Not set",
                              style: TextStyle(color: businessGSTIN != null && businessGSTIN!.isNotEmpty ? Colors.white : Colors.white38, fontSize: 10, fontWeight: businessGSTIN != null && businessGSTIN!.isNotEmpty ? FontWeight.w800 : FontWeight.w500, fontStyle: businessGSTIN != null && businessGSTIN!.isNotEmpty ? FontStyle.normal : FontStyle.italic),
                            ),
                          if (_showLicenseNumber)
                            Text(
                              businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty ? "License: $businessLicenseNumber" : "License: Not set",
                              style: TextStyle(color: businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty ? Colors.white70 : Colors.white38, fontSize: 10, fontStyle: businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty ? FontStyle.normal : FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                    if (_showCustomerDetails && widget.customerName != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("TO", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(widget.customerName!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                            if (widget.customerPhone != null) Text("Ph: ${widget.customerPhone}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                            if (widget.customerGSTIN != null) Text("GSTIN: ${widget.customerGSTIN}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _buildDetailedBody(colors),
        ],
      ),
    );
  }

  Widget _buildDetailedBody(Map<String, Color> colors) {
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildTableHeader(colors),
        _buildItemsList(colors),
        _buildSummary(colors),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors['headerBg']),
          child: Row(
            children: [
              Icon(Icons.payment_rounded, color: colors['primary'], size: 18),
              const SizedBox(width: 12),
              Text("Payment: ${widget.paymentMode.toUpperCase()}", style: TextStyle(color: colors['text'], fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SHARED TABLE COMPONENTS
  // ==========================================

  Widget _buildTableHeader(Map<String, Color> colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: colors['headerBg'],
        border: Border.symmetric(horizontal: BorderSide(color: colors['primary']!.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Expanded(flex: 7, child: Text('PRODUCT', softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          if (_showMeasuringUnit)
            Expanded(flex: 2, child: Text('UNIT', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 3, child: Text('QTY', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          if (_showMRP)
            Expanded(flex: 3, child: Text('MRP', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 4, child: Text('RATE', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 3, child: Text('TAX %', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 5, child: Text('TAX AMT', textAlign: TextAlign.center, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
          Expanded(flex: 6, child: Text('TOTAL', textAlign: TextAlign.right, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildItemsList(Map<String, Color> colors) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final bool isLast = index == widget.items.length - 1;
        final double taxVal = (item['taxAmount'] ?? 0.0).toDouble();
        final int taxPerc = (item['taxPercentage'] ?? 0).toInt();
        final String unit = item['unit'] ?? 'pcs';
        final double mrp = (item['mrp'] ?? item['price'] ?? 0.0).toDouble();

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            border: isLast ? null : const Border(bottom: BorderSide(color: kGrey100)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 7, child: Text(item['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: kBlack87), maxLines: 2, overflow: TextOverflow.ellipsis)),
              if (_showMeasuringUnit)
                Expanded(flex: 2, child: Text(unit, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: kBlack54, fontWeight: FontWeight.w600))),
              Expanded(flex: 3, child: Text('${item['quantity']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700))),
              if (_showMRP)
                Expanded(flex: 3, child: Text(mrp.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700, decoration: TextDecoration.lineThrough))),
              Expanded(flex: 4, child: Text('${item['price'].toStringAsFixed(0)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700))),
              Expanded(flex: 3, child: Text(taxPerc > 0 ? '$taxPerc%' : '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700))),
              Expanded(flex: 5, child: Text(taxVal > 0 ? taxVal.toStringAsFixed(0) : '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w700))),
              Expanded(flex: 6, child: Text('${(item['total'] ?? 0.0).toStringAsFixed(0)}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: colors['primary']))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary(Map<String, Color> colors) {
    // Calculate total qty
    double totalQty = 0;
    double totalMRP = 0;
    for (final item in widget.items) {
      final qty = (item['quantity'] is int)
          ? (item['quantity'] as int).toDouble()
          : (item['quantity'] ?? 1.0).toDouble();
      totalQty += qty;
      // Calculate MRP total for savings calculation (regardless of _showMRP toggle)
      if (item['mrp'] != null) {
        final mrp = (item['mrp'] is int) ? (item['mrp'] as int).toDouble() : (item['mrp'] as double);
        totalMRP += mrp * qty;
      }
    }

    // Calculate savings (MRP - actual total) - works when items have MRP values
    final savings = _showSaveAmountMessage && totalMRP > 0 && totalMRP > widget.total
        ? totalMRP - widget.total
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Total Items
          if (_showTotalItems)
            _summaryRow("Total Items", widget.items.length.toDouble(), colors, isCount: true),

          // Total Qty
          if (_showTotalQty)
            _summaryRow("Total Qty", totalQty.toDouble(), colors, isCount: true),

          _summaryRow("Subtotal Gross", widget.subtotal, colors),
          if (widget.discount > 0) _summaryRow("Applied Discount", widget.discount, colors, isNegative: true),
          if (widget.taxes != null)
            ...widget.taxes!.map((tax) => _summaryRow(
              tax['name'].toString(),
              (tax['amount'] ?? 0.0) as double,
              colors,
            )),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: kGrey100)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("NET PAYABLE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5)),
              Text(
                "Rs ${widget.total.toStringAsFixed(2)}",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colors['primary']),
              ),
            ],
          ),

          // Payment Mode
          if (_showPaymentMode)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Payment Mode", style: TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kGoogleGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.paymentMode.toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: kGoogleGreen, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),

          // Customer Save Amount Message
          if (_showSaveAmountMessage && savings > 0)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kGoogleGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGoogleGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.savings_rounded, color: kGoogleGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "You saved${savings.toStringAsFixed(0)} on this order!",
                    style: const TextStyle(fontSize: 12, color: kGoogleGreen, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, Map<String, Color> colors, {bool isNegative = false, bool isCount = false}) {
    // For count values, show as integer if whole number, otherwise show decimals
    String displayValue;
    if (isCount) {
      displayValue = amount == amount.roundToDouble() ? amount.toInt().toString() : amount.toStringAsFixed(2);
    } else {
      displayValue = "${isNegative ? '-' : ''}${amount.toStringAsFixed(2)}";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w600)),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isNegative ? kErrorColor : kBlack87,
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Action Bar
  Widget _buildBottomActionBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: _bwBg,
          border: Border(top: BorderSide(color: kGrey200, width: 1.5)),
        ),
        child: Row(
          children: [
            _buildBtn(Icons.print_rounded, "PRINT", () => _handlePrint(context), true),
            const SizedBox(width: 12),
            _buildBtn(Icons.share_rounded, "SHARE", () => _handleShare(context), true),
            const SizedBox(width: 12),
            _buildBtn(Icons.add_rounded, "NEW SALE", () {
              Navigator.pushAndRemoveUntil(
                context,
                CupertinoPageRoute(builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.userEmail)),
                    (route) => false,
              );
            }, false),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(IconData icon, String label, VoidCallback onTap, bool isSec) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSec ? kWhite : kPrimaryColor,
          foregroundColor: isSec ? kPrimaryColor : kWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSec ? const BorderSide(color: kPrimaryColor, width: 1.5) : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  // Logic Implementations
  Future<void> _handlePrint(BuildContext context) async {
    try {
      // System Bluetooth check & prompt to turn on
      BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState == BluetoothAdapterState.off) {
        if (Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
            await Future.delayed(const Duration(seconds: 1));
            adapterState = await FlutterBluePlus.adapterState.first;
          } catch (e) {
            debugPrint('Bluetooth turnOn error: $e');
          }
        }
      }

      if (adapterState != BluetoothAdapterState.on) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: kWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('BLUETOOTH REQUIRED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87)),
              content: const Text('Bluetooth is currently disabled. Please enable it in settings to connect with your printer.', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w500)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800, color: kPrimaryColor)),
                ),
              ],
            ),
          );
        }
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            color: _bwBg,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: kPrimaryColor),
                  SizedBox(height: 16),
                  Text('PRINTING...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                ],
              ),
            ),
          ),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final selectedPrinterId = prefs.getString('selected_printer_id');

      // Get printer width setting (default to 58mm / 32 chars)
      // 58mm = 32 characters, 80mm = 48 characters
      final printerWidth = prefs.getString('printer_width') ?? '58mm';
      final int lineWidth = printerWidth == '80mm' ? 48 : 32;
      final String dividerLine = '=' * lineWidth;
      final String thinDivider = '-' * lineWidth;

      if (selectedPrinterId == null) {
        Navigator.pop(context);
        CommonWidgets.showSnackBar(context, "No printer configured", bgColor: kOrange);
        return;
      }

      final devices = await FlutterBluePlus.bondedDevices;
      final device = devices.firstWhere(
            (d) => d.remoteId.toString() == selectedPrinterId,
        orElse: () => throw Exception('Printer not found'),
      );

      if (device.isConnected == false) {
        await device.connect(timeout: const Duration(seconds: 10));
        await Future.delayed(const Duration(milliseconds: 500));
      }

      List<int> bytes = [];
      const esc = 0x1B;
      const gs = 0x1D;
      const lf = 0x0A;

      // Init Printer
      bytes.addAll([esc, 0x40]);

      // ========== HEADER SECTION ==========
      bytes.addAll([esc, 0x61, 0x01]); // Center align

      // Business Name (Bold, Large)
      bytes.addAll([esc, 0x21, 0x30]); // Double height + width + bold
      bytes.addAll(utf8.encode(_truncateText(businessName.toUpperCase(), lineWidth ~/ 2)));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]); // Reset to normal

      // Location
      if (_showLocation && businessLocation.isNotEmpty) {
        bytes.addAll(utf8.encode(_truncateText(businessLocation, lineWidth)));
        bytes.add(lf);
      }

      // Phone
      if (_showPhone && businessPhone.isNotEmpty) {
        bytes.addAll(utf8.encode('Tel: $businessPhone'));
        bytes.add(lf);
      }

      // Email
      if (_showEmail && businessEmail != null && businessEmail!.isNotEmpty) {
        bytes.addAll(utf8.encode(_truncateText('Email: $businessEmail', lineWidth)));
        bytes.add(lf);
      }

      // GST Number
      if (_showGST && businessGSTIN != null && businessGSTIN!.isNotEmpty) {
        bytes.addAll([esc, 0x21, 0x08]); // Bold
        bytes.addAll(utf8.encode('TAX NO: $businessGSTIN'));
        bytes.add(lf);
        bytes.addAll([esc, 0x21, 0x00]); // Reset
      }

      // License Number
      if (_showLicenseNumber && businessLicenseNumber != null && businessLicenseNumber!.isNotEmpty) {
        bytes.addAll(utf8.encode('License: $businessLicenseNumber'));
        bytes.add(lf);
      }

      bytes.add(lf);
      bytes.addAll(utf8.encode(dividerLine));
      bytes.add(lf);

      // ========== INVOICE DETAILS ==========
      bytes.addAll([esc, 0x61, 0x00]); // Left align

      // Invoice Number and Date on same line for 80mm, separate for 58mm
      if (lineWidth >= 48) {
        String invLine = '${widget.isQuotation ? "QTN" : "INV"} #${widget.invoiceNumber}';
        String datePart = DateFormat('dd MMM yyyy').format(widget.dateTime);
        bytes.addAll(utf8.encode(invLine.padRight(lineWidth - datePart.length) + datePart));
        bytes.add(lf);
      } else {
        bytes.addAll(utf8.encode('${widget.isQuotation ? "QTN" : "INV"}: #${widget.invoiceNumber}'));
        bytes.add(lf);
        bytes.addAll(utf8.encode('Date: ${DateFormat('dd MMM yyyy').format(widget.dateTime)}'));
        bytes.add(lf);
      }

      // Customer Details
      if (_showCustomerDetails && widget.customerName != null) {
        bytes.addAll(utf8.encode(thinDivider));
        bytes.add(lf);
        bytes.addAll(utf8.encode('Bill To: ${_truncateText(widget.customerName!, lineWidth - 9)}'));
        bytes.add(lf);
        if (widget.customerPhone != null) {
          bytes.addAll(utf8.encode('Ph: ${widget.customerPhone}'));
          bytes.add(lf);
        }
      }

      bytes.addAll(utf8.encode(dividerLine));
      bytes.add(lf);

      // ========== ITEMS TABLE ==========
      // Dynamic column widths based on printer width
      int nameWidth, qtyWidth, rateWidth, taxWidth, totalWidth;

      if (lineWidth >= 48) {
        // 80mm printer - more space
        nameWidth = 16;
        qtyWidth = 4;
        rateWidth = 8;
        taxWidth = 6;
        totalWidth = 10;
      } else {
        // 58mm printer - compact
        nameWidth = 10;
        qtyWidth = 3;
        rateWidth = 6;
        taxWidth = 4;
        totalWidth = 7;
      }

      // Build header based on what's shown
      String header = 'ITEM'.padRight(nameWidth);
      header += 'QTY  '.padRight(qtyWidth);
      header += 'RATE'.padRight(rateWidth);
      header += 'TAX'.padRight(taxWidth);
      header += 'TOTAL'.padLeft(totalWidth);

      bytes.addAll([esc, 0x21, 0x08]); // Bold
      bytes.addAll(utf8.encode(_truncateText(header, lineWidth)));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]); // Reset
      bytes.addAll(utf8.encode(thinDivider));
      bytes.add(lf);

      // Calculate totals
      int totalItems = widget.items.length;
      double totalQty = 0;
      double totalMRP = 0;

      // Items - Single line per item
      for (var item in widget.items) {
        final name = (item['name'] ?? 'Item').toString();
        final qty = (item['quantity'] ?? 1).toDouble();
        final mrp = (item['mrp'] ?? item['price'] ?? 0).toDouble();
        final rate = (item['price'] ?? 0).toDouble();
        final taxPercent = (item['taxPercentage'] ?? 0).toDouble();
        final total = (item['total'] ?? (rate * qty)).toDouble();

        totalQty += qty;
        totalMRP += mrp * qty;

        // Build single item line
        String itemLine = '';
        itemLine += _truncateText(name, nameWidth - 1).padRight(nameWidth);
        // Show quantity with decimals if it's not a whole number
        final qtyStr = qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);
        itemLine += qtyStr.padRight(qtyWidth);
        itemLine += _formatPrice(rate, rateWidth - 1).padRight(rateWidth);
        itemLine += '${taxPercent.toInt()}%'.padRight(taxWidth);
        itemLine += _formatPrice(total, totalWidth).padLeft(totalWidth);

        bytes.addAll(utf8.encode(itemLine));
        bytes.add(lf);
      }

      bytes.addAll(utf8.encode(thinDivider));
      bytes.add(lf);

      // ========== SUMMARY SECTION ==========
      int labelWidth = lineWidth >= 48 ? 28 : 18;
      int valueWidth = lineWidth - labelWidth;

      // Total Items
      if (_showTotalItems) {
        bytes.addAll(utf8.encode('Total Items:'.padRight(labelWidth) + totalItems.toString().padLeft(valueWidth)));
        bytes.add(lf);
      }

      // Total Qty
      if (_showTotalQty) {
        final totalQtyStr = totalQty == totalQty.roundToDouble() ? totalQty.toInt().toString() : totalQty.toStringAsFixed(2);
        bytes.addAll(utf8.encode('Total Qty:'.padRight(labelWidth) + totalQtyStr.padLeft(valueWidth)));
        bytes.add(lf);
      }

      // Subtotal
      bytes.addAll(utf8.encode('Subtotal:'.padRight(labelWidth) + widget.subtotal.toStringAsFixed(2).padLeft(valueWidth)));
      bytes.add(lf);

      // Taxes
      if (widget.taxes != null) {
        for (var tax in widget.taxes!) {
          final taxName = (tax['name'] ?? 'Tax').toString();
          final taxAmount = (tax['amount'] ?? 0.0).toDouble();
          bytes.addAll(utf8.encode('$taxName:'.padRight(labelWidth) + taxAmount.toStringAsFixed(2).padLeft(valueWidth)));
          bytes.add(lf);
        }
      }

      // Discount
      if (widget.discount > 0) {
        bytes.addAll(utf8.encode('Discount:'.padRight(labelWidth) + '-${widget.discount.toStringAsFixed(2)}'.padLeft(valueWidth)));
        bytes.add(lf);
      }

      bytes.addAll(utf8.encode(dividerLine));
      bytes.add(lf);

      // NET PAYABLE (Bold)
      bytes.addAll([esc, 0x21, 0x10]); // Double height + bold
      String totalLine = 'TOTAL:'.padRight(labelWidth) + 'Rs ${widget.total.toStringAsFixed(2)}'.padLeft(valueWidth);
      bytes.addAll(utf8.encode(totalLine));
      bytes.add(lf);
      bytes.addAll([esc, 0x21, 0x00]); // Reset

      // Payment Mode
      if (_showPaymentMode) {
        bytes.addAll(utf8.encode('Paid:'.padRight(labelWidth) + widget.paymentMode.toUpperCase().padLeft(valueWidth)));
        bytes.add(lf);
      }

      bytes.addAll(utf8.encode(dividerLine));
      bytes.add(lf);

      // ========== FOOTER ==========
      bytes.addAll([esc, 0x61, 0x01]); // Center

      // Customer Savings Message
      if (_showSaveAmountMessage && totalMRP > widget.total) {
        double savings = totalMRP - widget.total;
        bytes.addAll(utf8.encode('You saved Rs ${savings.toStringAsFixed(2)}!'));
        bytes.add(lf);
      }

      // Footer Description
      bytes.add(lf);
      if (!widget.isQuotation && _footerDescription.isNotEmpty) {
        bytes.addAll([esc, 0x21, 0x08]); // Bold
        bytes.addAll(utf8.encode(_truncateText(_footerDescription.toUpperCase(), lineWidth)));
        bytes.addAll([esc, 0x21, 0x00]); // Reset
        bytes.add(lf);
      }

      // Quotation Footer
      if (widget.isQuotation && _quotationFooterDescription.isNotEmpty) {
        bytes.addAll([esc, 0x21, 0x08]); // Bold
        bytes.addAll(utf8.encode(_truncateText(_quotationFooterDescription.toUpperCase(), lineWidth)));
        bytes.addAll([esc, 0x21, 0x00]); // Reset
        bytes.add(lf);
      }

      bytes.add(lf);
      bytes.add(lf);
      bytes.add(lf);
      bytes.addAll([gs, 0x56, 0x00]); // Cut

      final services = await device.discoverServices();
      BluetoothCharacteristic? writeChar;
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.write) { writeChar = c; break; }
        }
      }
      if (writeChar != null) {
        const chunk = 20;
        for (int i = 0; i < bytes.length; i += chunk) {
          final end = (i + chunk < bytes.length) ? i + chunk : bytes.length;
          await writeChar.write(bytes.sublist(i, end), withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }
      Navigator.pop(context);
      CommonWidgets.showSnackBar(context, 'Receipt printed successfully', bgColor: kGoogleGreen);
    } catch (e) {
      Navigator.pop(context);
      CommonWidgets.showSnackBar(context, 'Printing failed: $e', bgColor: kErrorColor);
    }
  }

  // Helper: Truncate text to fit width
  String _truncateText(String text, int maxWidth) {
    if (text.length <= maxWidth) return text;
    return '${text.substring(0, maxWidth - 1)}.';
  }

  // Helper: Format price to fit width
  String _formatPrice(double price, int maxWidth) {
    String priceStr = price.toStringAsFixed(0);
    if (priceStr.length > maxWidth) {
      // Use K notation for large numbers
      if (price >= 1000) {
        priceStr = '${(price / 1000).toStringAsFixed(1)}K';
      }
    }
    return priceStr.length > maxWidth ? priceStr.substring(0, maxWidth) : priceStr;
  }

  Future<void> _handleShare(BuildContext context) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: kPrimaryColor)));

      final pdf = pw.Document();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [_buildPdfByTemplate(_selectedTemplate)];
        },
      ));

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/invoice_${widget.invoiceNumber}.pdf');
      await file.writeAsBytes(await pdf.save());
      Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)], subject: 'Invoice #${widget.invoiceNumber}');
    } catch (e) {
      Navigator.pop(context);
      debugPrint('Error generating PDF: $e');
    }
  }

  pw.Widget _buildPdfByTemplate(InvoiceTemplate template) {
    switch (template) {
      case InvoiceTemplate.classic: return _buildClassicPdf();
      case InvoiceTemplate.modern: return _buildModernPdf();
      case InvoiceTemplate.minimal: return _buildCompactPdf();
      case InvoiceTemplate.colorful: return _buildDetailedPdf();
    }
  }

  pw.Widget _buildClassicPdf() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(30),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.5)),
      child: pw.Column(
        children: [
          pw.Center(child: pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 10))),
          if (_showPhone) pw.Center(child: pw.Text("Tel: $businessPhone", style: const pw.TextStyle(fontSize: 10))),
          pw.Divider(color: PdfColors.black, height: 30),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("${widget.isQuotation ? 'QUOTATION' : 'INVOICE'} #${widget.invoiceNumber}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text("DATE: ${DateFormat('dd MMM yyyy').format(widget.dateTime)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ]),
          pw.SizedBox(height: 16),
          if (widget.customerName != null) ...[
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("BILL TO: ${widget.customerName!.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              if (widget.customerPhone != null) pw.Text(widget.customerPhone!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ]),
            pw.SizedBox(height: 16),
          ],
          ..._buildPdfItemsTable(PdfColors.black),
          pw.SizedBox(height: 20),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text("Subtotal Gross: ${widget.subtotal.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10)),
                if (widget.discount > 0) pw.Text("Applied Discount: -${widget.discount.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10)),
                if (widget.taxes != null)
                  ...widget.taxes!.map((tax) => pw.Text("${tax['name']}:${(tax['amount'] ?? 0.0).toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10))),
                pw.Divider(color: PdfColors.black, thickness: 1),
                pw.Text("NET TOTAL:${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modern Template PDF
  pw.Widget _buildModernPdf() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue, width: 2),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: const pw.BoxDecoration(color: PdfColors.blue, borderRadius: pw.BorderRadius.only(topLeft: pw.Radius.circular(10), topRight: pw.Radius.circular(10))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(businessName, style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text(businessLocation, style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                    if (_showPhone) pw.Text("Tel: $businessPhone", style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(widget.isQuotation ? "QUOTATION" : "TAX INVOICE", style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text("#${widget.invoiceNumber}", style: const pw.TextStyle(color: PdfColors.white, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              children: [
                if (widget.customerName != null) ...[
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text("BILL TO", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                      pw.Text(widget.customerName!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.Text(DateFormat('dd MMM yyyy').format(widget.dateTime), style: const pw.TextStyle(fontSize: 10)),
                  ]),
                  pw.SizedBox(height: 20),
                ],
                ..._buildPdfItemsTable(PdfColors.blue),
                pw.SizedBox(height: 20),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Gross Subtotal: ${widget.subtotal.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10)),
                      if (widget.taxes != null)
                        ...widget.taxes!.map((tax) => pw.Text("${tax['name']}:${(tax['amount'] ?? 0.0).toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10))),
                      pw.Divider(color: PdfColors.blue),
                      pw.Text("NET TOTAL:${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Compact Template PDF
  pw.Widget _buildCompactPdf() {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey800)),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            color: PdfColors.grey200,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(businessName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 9)),
                    if (_showPhone) pw.Text("Tel: $businessPhone", style: const pw.TextStyle(fontSize: 9)),
                    if (_showGST && businessGSTIN != null) pw.Text("GSTIN: $businessGSTIN", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("INV: #${widget.invoiceNumber}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd MMM yyyy').format(widget.dateTime), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              children: [
                if (widget.customerName != null) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("CLIENT: ${widget.customerName!.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],
                ..._buildPdfItemsTable(PdfColors.black),
                pw.SizedBox(height: 16),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Subtotal: ${widget.subtotal.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 9)),
                      if (widget.taxes != null)
                        ...widget.taxes!.map((tax) => pw.Text("${tax['name']}: ${(tax['amount'] ?? 0.0).toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 9))),
                      pw.Divider(),
                      pw.Text("TOTAL:${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Detailed Creative Template PDF
  pw.Widget _buildDetailedPdf() {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.purple, width: 2.5)),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: const pw.BoxDecoration(color: PdfColors.purple),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(widget.isQuotation ? "QUOTATION" : "TAX INVOICE", style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                    pw.Text("#${widget.invoiceNumber}", style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColors.white),
                pw.SizedBox(height: 16),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("FROM", style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text(businessName, style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          pw.Text(businessLocation, style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                          if (_showGST && businessGSTIN != null) pw.Text("GSTIN: $businessGSTIN", style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                        ],
                      ),
                    ),
                    if (widget.customerName != null)
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("TO", style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text(widget.customerName!, style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                            if (widget.customerPhone != null) pw.Text("Ph: ${widget.customerPhone}", style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              children: [
                ..._buildPdfItemsTable(PdfColors.purple),
                pw.SizedBox(height: 20),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Subtotal: ${widget.subtotal.toStringAsFixed(2)}"),
                      if (widget.discount > 0) pw.Text("Discount: -${widget.discount.toStringAsFixed(2)}"),
                      if (widget.taxes != null)
                        ...widget.taxes!.map((tax) => pw.Text("${tax['name']}:${(tax['amount'] ?? 0.0).toStringAsFixed(2)}")),
                      pw.Divider(color: PdfColors.purple),
                      pw.Text("TOTAL DUE:${widget.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.purple)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PDF SHARED COMPONENTS (6-COLUMN TABLE)
  // ==========================================

  List<pw.Widget> _buildPdfItemsTable(PdfColor primary) {
    return [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(7),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FlexColumnWidth(4),
          3: const pw.FlexColumnWidth(3),
          4: const pw.FlexColumnWidth(5),
          5: const pw.FlexColumnWidth(6),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              _pdfHeaderCell("PRODUCT"),
              _pdfHeaderCell("QTY"),
              _pdfHeaderCell("RATE"),
              _pdfHeaderCell("TAX %"),
              _pdfHeaderCell("TAX AMT"),
              _pdfHeaderCell("TOTAL", align: pw.TextAlign.right),
            ],
          ),
          ...widget.items.map((item) {
            final double taxVal = (item['taxAmount'] ?? 0.0).toDouble();
            final int taxPerc = (item['taxPercentage'] ?? 0).toInt();
            return pw.TableRow(
              children: [
                _pdfDataCell(item['name'] ?? 'Item'),
                _pdfDataCell("${item['quantity']}"),
                _pdfDataCell("${(item['price'] ?? 0).toStringAsFixed(0)}"),
                _pdfDataCell(taxPerc > 0 ? "$taxPerc%" : "-"),
                _pdfDataCell(taxVal > 0 ? taxVal.toStringAsFixed(0) : "-"),
                _pdfDataCell("${(item['total'] ?? 0.0).toStringAsFixed(0)}", align: pw.TextAlign.right, isBold: true, color: primary),
              ],
            );
          }),
        ],
      ),
    ];
  }

  pw.Widget _pdfHeaderCell(String label, {pw.TextAlign align = pw.TextAlign.center}) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(label, textAlign: align, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)));
  pw.Widget _pdfDataCell(String label, {pw.TextAlign align = pw.TextAlign.center, bool isBold = false, PdfColor? color}) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(label, textAlign: align, style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.black)));
}

// Confetti particle class for celebration animation
class _Confetti {
  double x;
  double y;
  final Color color;
  final double size;
  final double speed;
  double rotation;

  _Confetti({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.speed,
    required this.rotation,
  });
}

// Custom painter for confetti animation
class _ConfettiPainter extends CustomPainter {
  final List<_Confetti> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      // Update particle position based on progress
      final y = particle.y + (progress * particle.speed * 3);
      final x = particle.x + (sin(progress * 10 + particle.rotation) * 0.05);

      // Only draw if particle is visible
      if (y > 0 && y < 1.2) {
        final paint = Paint()
          ..color = particle.color.withOpacity(1.0 - progress * 0.7)
          ..style = PaintingStyle.fill;

        canvas.save();
        canvas.translate(x * size.width, y * size.height);
        canvas.rotate(particle.rotation + progress * 5);

        // Draw rectangle confetti
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: particle.size, height: particle.size * 0.6),
          paint,
        );

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

