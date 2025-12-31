import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';

// Imports from your project structure
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/Auth/LoginPage.dart';
import 'package:maxbillup/Auth/SubscriptionPlanPage.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/theme_notifier.dart';
import 'package:maxbillup/utils/language_provider.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/Settings/TaxSettings.dart' as TaxSettingsNew;

// ==========================================
// CONSTANTS & STYLES
// ==========================================
const Color kPrimaryColor = Color(0xFF2F7CF6);
const Color kBlack87 = Color(0xDD000000);
const Color kBlack54 = Color(0x8A000000);
const Color kGreyBg = Color(0xFFF5F5F5);
const Color kGrey300 = Color(0xFFE0E0E0);
const Color kErrorColor = Colors.red;
final Color kBgColor = const Color(0xFFF9FAFC);
const Color kSurfaceColor = Colors.white;
const Color kInputFillColor = Color(0xFFF0F8FF);
const Color kDangerColor = Color(0xFFFF3B30);
const Color kTextPrimary = Color(0xFF1D1D1D);
const Color kTextSecondary = Color(0xFF8A8A8E);
final Color kBorderColor = Color(0xFFE3F2FD);

// Feature Colors for Settings Icons
const Color kColorBusiness = Color(0xFF1976D2);
const Color kColorReceipt = Color(0xFFFF9800);
const Color kColorTax = Color(0xFF43A047);
const Color kColorPrinter = Color(0xFF9C27B0);

// ==========================================
// 1. MAIN SETTINGS PAGE
// ==========================================
class SettingsPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  const SettingsPage({super.key, required this.uid, this.userEmail});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _currentView;
  final List<String> _viewHistory = [];
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _storeData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      final userData = userDoc.exists ? userDoc.data() : null;
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      final storeData = (storeDoc != null && storeDoc.exists) ? (storeDoc.data() as Map<String, dynamic>?) : null;

      if (mounted) {
        setState(() {
          _userData = userData;
          _storeData = storeData;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateTo(String view) {
    setState(() {
      if (_currentView != null) _viewHistory.add(_currentView!);
      _currentView = view;
    });
  }

  void _goBack() {
    setState(() {
      if (_viewHistory.isNotEmpty) {
        _currentView = _viewHistory.removeLast();
      } else {
        _currentView = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // View Routing
    if (_currentView != null) {
      switch (_currentView) {
        case 'BusinessDetails':
          return BusinessDetailsPage(uid: widget.uid, onBack: _goBack);
        case 'ReceiptSettings':
          return ReceiptSettingsPage(onBack: _goBack, onNavigate: _navigateTo, uid: widget.uid, userEmail: widget.userEmail);
        case 'ReceiptCustomization':
          return ReceiptCustomizationPage(onBack: _goBack);
        case 'TaxSettings':
          return TaxSettingsNew.TaxSettingsPage(uid: widget.uid);
        case 'PrinterSetup':
          return PrinterSetupPage(onBack: _goBack);
        case 'FeatureSettings':
          return FeatureSettingsPage(onBack: _goBack);
        case 'Language':
          return LanguagePage(onBack: _goBack);
        case 'Theme':
          return ThemePage(onBack: _goBack);
        case 'Help':
          return HelpPage(onBack: _goBack, onNavigate: _navigateTo);
        case 'FAQs':
          return FAQsPage(onBack: _goBack);
        case 'UpcomingFeatures':
          return UpcomingFeaturesPage(onBack: _goBack);
        case 'VideoTutorials':
          return VideoTutorialsPage(onBack: _goBack);
      }
    }

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: Text(context.tr('settings'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true, // Centered title
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 24),
          _buildSectionTitle("App Settings"),
          _buildModernTile(
            title: context.tr('business_details'),
            icon: Icons.store_mall_directory_rounded,
            color: kColorBusiness,
            onTap: () => _navigateTo('BusinessDetails'),
            subtitle: "Manage business profile",
          ),
          _buildModernTile(
            title: context.tr('receipt_customization'),
            icon: Icons.receipt_long_rounded,
            color: kColorReceipt,
            onTap: () => _navigateTo('ReceiptSettings'),
            subtitle: "Templates & Format",
          ),
          _buildModernTile(
            title: context.tr('tax_settings'),
            icon: Icons.percent_rounded,
            color: kColorTax,
            onTap: () => _navigateTo('TaxSettings'),
            subtitle: "GST, VAT & more",
          ),
          _buildModernTile(
            title: context.tr('printer_setup'),
            icon: Icons.print_rounded,
            color: kColorPrinter,
            onTap: () => _navigateTo('PrinterSetup'),
            subtitle: "Bluetooth printers",
          ),
          _buildModernTile(
            title: 'Language',
            icon: Icons.language_rounded,
            color: const Color(0xFF12008C),
            onTap: () => _navigateTo('Language'),
            subtitle: "Choose language",
          ),
          const SizedBox(height: 24),
          const Center(child: Text('Version 1.0.0', style: TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w500))),
          const SizedBox(height: 16),
          _buildLogoutButton(),
          const SizedBox(height: 30),
        ],
      ),
      bottomNavigationBar: CommonBottomNav(
        uid: widget.uid,
        userEmail: widget.userEmail,
        currentIndex: 4,
        screenWidth: screenWidth,
      ),
    );
  }

  Widget _buildProfileCard() {
    final name = _storeData?['businessName'] ?? _userData?['businessName'] ?? _userData?['name'] ?? 'User';
    final email = _userData?['email'] ?? widget.userEmail ?? '';
    final logoUrl = _storeData?['logoUrl'] ?? '';

    final planProvider = Provider.of<PlanProvider>(context);
    return FutureBuilder<String>(
      future: planProvider.getCurrentPlan(),
      builder: (context, snapshot) {
        final plan = snapshot.data ?? 'Free';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorderColor),
            boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (logoUrl.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(16),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: InteractiveViewer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(logoUrl, fit: BoxFit.contain, key: ValueKey(logoUrl)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: kGreyBg, shape: BoxShape.circle,
                    border: Border.all(color: kGrey200, width: 2),
                    image: logoUrl.isNotEmpty ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover) : null,
                  ),
                  child: logoUrl.isEmpty ? const Icon(Icons.image, size: 30, color: kGrey400) : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                          child: Text(plan, style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                    if (plan != 'Pro') ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          await Navigator.push(context, CupertinoPageRoute(builder: (context) => SubscriptionPlanPage(uid: widget.uid, currentPlan: plan)));
                          if (mounted) setState(() {});
                        },
                        child: const Text('Upgrade Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernTile({required String title, required IconData icon, required Color color, required VoidCallback onTap, String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorderColor),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kTextPrimary)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: kTextSecondary, fontSize: 12)) : null,
        trailing: Icon(Icons.chevron_right_rounded, color: kTextSecondary.withOpacity(0.5), size: 24),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          FirestoreService().clearCache();
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(CupertinoPageRoute(builder: (_) => const LoginPage()), (r) => false);
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kDangerColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kDangerColor)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(title.toUpperCase(), style: const TextStyle(color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
  );
}

// ==========================================
// 2. BUSINESS DETAILS PAGE
// ==========================================
class BusinessDetailsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;
  const BusinessDetailsPage({super.key, required this.uid, required this.onBack});
  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(), _phoneCtrl = TextEditingController(), _gstCtrl = TextEditingController(), _licenseCtrl = TextEditingController(), _locCtrl = TextEditingController(), _emailCtrl = TextEditingController(), _ownerCtrl = TextEditingController();
  final _locationFocusNode = FocusNode();
  bool _editing = false, _loading = false, _fetching = true, _uploadingImage = false;
  String? _logoUrl;
  File? _selectedImage;
  String _selectedCurrency = 'INR'; // Default to Indian Rupee

  // Currency list with symbols and codes
  final List<Map<String, String>> _currencies = [
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'SAR', 'symbol': '﷼', 'name': 'Saudi Riyal'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan (RMB)'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    {'code': 'CHF', 'symbol': 'CHF', 'name': 'Swiss Franc'},
    {'code': 'KRW', 'symbol': '₩', 'name': 'South Korean Won'},
    {'code': 'THB', 'symbol': '฿', 'name': 'Thai Baht'},
    {'code': 'PHP', 'symbol': '₱', 'name': 'Philippine Peso'},
    {'code': 'IDR', 'symbol': 'Rp', 'name': 'Indonesian Rupiah'},
    {'code': 'VND', 'symbol': '₫', 'name': 'Vietnamese Dong'},
    {'code': 'BDT', 'symbol': '৳', 'name': 'Bangladeshi Taka'},
    {'code': 'PKR', 'symbol': '₨', 'name': 'Pakistani Rupee'},
    {'code': 'LKR', 'symbol': 'Rs', 'name': 'Sri Lankan Rupee'},
    {'code': 'NPR', 'symbol': 'Rs', 'name': 'Nepalese Rupee'},
    {'code': 'ZAR', 'symbol': 'R', 'name': 'South African Rand'},
    {'code': 'BRL', 'symbol': 'R\$', 'name': 'Brazilian Real'},
    {'code': 'MXN', 'symbol': 'Mex\$', 'name': 'Mexican Peso'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _gstCtrl.addListener(() => setState(() {}));
  }
  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _gstCtrl.dispose(); _licenseCtrl.dispose(); _locCtrl.dispose(); _emailCtrl.dispose(); _ownerCtrl.dispose(); _locationFocusNode.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _fetching = true);
    try {
      final store = await FirestoreService().getCurrentStoreDoc();
      final user = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (store != null && store.exists) {
        final data = store.data() as Map<String, dynamic>;
        _nameCtrl.text = data['businessName'] ?? '';
        _phoneCtrl.text = data['businessPhone'] ?? '';
        _gstCtrl.text = data['gstin'] ?? '';
        _licenseCtrl.text = data['licenseNumber'] ?? '';
        _selectedCurrency = data['currency'] ?? 'INR';
        _locCtrl.text = data['businessLocation'] ?? '';
        _ownerCtrl.text = data['ownerName'] ?? '';
        _logoUrl = data['logoUrl'];

        // Fast fetching: Precache the image immediately
        if (_logoUrl != null && _logoUrl!.isNotEmpty) {
          precacheImage(NetworkImage(_logoUrl!), context);
        }
      }
      if (user.exists) {
        final uData = user.data() as Map<String, dynamic>;
        _emailCtrl.text = uData['email'] ?? '';
        if (_ownerCtrl.text.isEmpty) _ownerCtrl.text = uData['name'] ?? '';
      }
    } catch (e) { debugPrint(e.toString()); }
    finally { if (mounted) setState(() => _fetching = false); }
  }

  void _showFullLogo() {
    if (_logoUrl == null || _logoUrl!.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(_logoUrl!, fit: BoxFit.contain, key: ValueKey(_logoUrl)),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (pickedFile != null) {
      // API FIX: aspectRatioPresets moved inside uiSettings platform blocks
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Logo',
            toolbarColor: kPrimaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Crop Logo',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() => _selectedImage = File(croppedFile.path));
        await _uploadImage();
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;
    setState(() => _uploadingImage = true);
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) throw Exception('Identity Error');
      final storageRef = FirebaseStorage.instance.ref().child('store_logos').child('$storeId.jpg');

      final uploadTask = await storageRef.putFile(_selectedImage!);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('store').doc(storeId).set({
        'logoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));

      await FirestoreService().notifyStoreDataChanged();

      if (mounted) {
        setState(() {
          _logoUrl = downloadUrl;
          _selectedImage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logo updated successfully!'), backgroundColor: Colors.green));
        await _loadData();
      }
    } catch (e) { debugPrint(e.toString()); }
    finally { if (mounted) setState(() => _uploadingImage = false); }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId != null) {
        await FirebaseFirestore.instance.collection('store').doc(storeId).set({
          'businessName': _nameCtrl.text.trim(),
          'businessPhone': _phoneCtrl.text.trim(),
          'gstin': _gstCtrl.text.trim(),
          'licenseNumber': _licenseCtrl.text.trim(),
          'currency': _selectedCurrency,
          'businessLocation': _locCtrl.text.trim(),
          'ownerName': _ownerCtrl.text.trim(),
          'updatedAt': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
          'name': _ownerCtrl.text.trim(),
          'businessLocation': _locCtrl.text.trim(),
          'updatedAt': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully"), backgroundColor: Colors.green));
          setState(() => _editing = false);
        }
      }
    } catch (e) { debugPrint(e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) { if (!didPop) { if (_editing) setState(() => _editing = false); else widget.onBack(); } },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
          title: const Text("Business Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: kPrimaryColor,
          centerTitle: true, // Centered title
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => _editing ? setState(() => _editing = false) : widget.onBack()),
          actions: [if (!_fetching) IconButton(icon: Icon(_editing ? Icons.check : Icons.edit_outlined, color: Colors.white), onPressed: () => _editing ? _save() : setState(() => _editing = true))],
        ),
        body: _fetching ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Center(child: Stack(children: [
                  GestureDetector(
                    onTap: _showFullLogo,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: kPrimaryColor, width: 3), boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.2), blurRadius: 10)]),
                      child: ClipOval(
                        child: _selectedImage != null
                            ? Image.file(_selectedImage!, fit: BoxFit.cover)
                            : _logoUrl != null && _logoUrl!.isNotEmpty
                            ? Image.network(_logoUrl!, fit: BoxFit.cover, key: ValueKey(_logoUrl))
                            : const Icon(Icons.store, size: 50, color: kPrimaryColor),
                      ),
                    ),
                  ),
                  Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: (_uploadingImage || !_editing) ? null : _pickImage, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: _editing ? kPrimaryColor : Colors.grey, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: _uploadingImage ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Icon(Icons.camera_alt, color: Colors.white, size: 18)))),
                ])),
                const SizedBox(height: 8),
                Text(
                  _editing ? "Tap logo to view or camera to change" : "Tap logo to view full screen",
                  style: TextStyle(color: _editing ? kPrimaryColor : kBlack54, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader("Identification"),
                _buildModernField("Business Name", _nameCtrl, Icons.store_rounded, enabled: _editing),
                _buildLocationField(),
                _buildModernField(
                    "Tax Number",
                    _gstCtrl,
                    Icons.receipt_long_rounded,
                    enabled: _editing,
                    hint: "Optional",
                    helperText: (_editing && _gstCtrl.text.isEmpty) ? "e.g. GST, VAT, SalesTax etc" : null
                ),
                _buildModernField(
                    "License Number",
                    _licenseCtrl,
                    Icons.badge_rounded,
                    enabled: _editing,
                    hint: "Optional",
                    helperText: (_editing && _licenseCtrl.text.isEmpty) ? "e.g. FSSAI - 12345678901234" : null
                ),
                _buildCurrencyField(),
                const SizedBox(height: 24),
                _buildSectionHeader("Ownership & Contact"),
                _buildModernField("Owner Name", _ownerCtrl, Icons.person_rounded, enabled: _editing),
                _buildModernField("Phone Number", _phoneCtrl, Icons.phone_android_rounded, enabled: _editing, type: TextInputType.phone),
                _buildModernField("Email Address", _emailCtrl, Icons.email_outlined, enabled: false, hint: "Locked"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.0))));

  Widget _buildModernField(String label, TextEditingController ctrl, IconData icon, {bool enabled = true, TextInputType type = TextInputType.text, String? hint, String? helperText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl, enabled: enabled, keyboardType: type,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          helperText: helperText,
          helperStyle: const TextStyle(color: kPrimaryColor, fontSize: 10, fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: enabled ? kPrimaryColor : Colors.grey[400], size: 20),
          filled: true, fillColor: enabled ? Colors.white : Colors.grey[100],
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGrey300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
        ),
        validator: (v) => (enabled && label == "Business Name" && (v == null || v.isEmpty)) ? "$label is required" : null,
      ),
    );
  }

  Widget _buildLocationField() {
    if (!_editing) return _buildModernField("Location", _locCtrl, Icons.location_on_rounded, enabled: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GooglePlaceAutoCompleteTextField(
        textEditingController: _locCtrl, focusNode: _locationFocusNode,
        googleAPIKey: "AIzaSyDXD9dhKhD6C8uB4ua9Nl04beav6qbtb3c",
        inputDecoration: InputDecoration(
          labelText: "Location", prefixIcon: const Icon(Icons.location_on_rounded, color: kPrimaryColor, size: 20),
          filled: true, fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGrey300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
        ),
        debounceTime: 600, countries: const ["in"], isLatLngRequired: false,
        itemClick: (p) { _locCtrl.text = p.description ?? ''; FocusScope.of(context).unfocus(); },
      ),
    );
  }

  Widget _buildCurrencyField() {
    final selectedCurrency = _currencies.firstWhere((c) => c['code'] == _selectedCurrency, orElse: () => _currencies[0]);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGrey300),
            ),
            child: ListTile(
              leading: const Icon(Icons.currency_exchange_rounded, color: kPrimaryColor, size: 20),
              title: const Text("Currency", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kBlack54)),
              subtitle: Text(
                "${selectedCurrency['symbol']} ${selectedCurrency['code']} - ${selectedCurrency['name']}",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
              ),
              trailing: _editing
                ? const Icon(Icons.arrow_drop_down, color: kPrimaryColor)
                : null,
              onTap: _editing ? _showCurrencyPicker : null,
              enabled: _editing,
            ),
          ),
          if (_editing)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 6),
              child: Text(
                "e.g. ₹ INR, \$ USD, € EUR, RM MYR, ¥ JPY",
                style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              "Select Currency",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kBlack87),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _currencies.length,
                itemBuilder: (context, index) {
                  final currency = _currencies[index];
                  final isSelected = currency['code'] == _selectedCurrency;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? kPrimaryColor.withAlpha((0.1 * 255).toInt()) : kGreyBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          currency['symbol']!,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? kPrimaryColor : kBlack87,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      "${currency['code']} - ${currency['name']}",
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? kPrimaryColor : kBlack87,
                      ),
                    ),
                    trailing: isSelected
                      ? const Icon(Icons.check_circle, color: kPrimaryColor)
                      : null,
                    onTap: () {
                      setState(() {
                        _selectedCurrency = currency['code']!;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. PRINTER SETUP PAGE
// ==========================================
class PrinterSetupPage extends StatefulWidget {
  final VoidCallback onBack;
  const PrinterSetupPage({super.key, required this.onBack});
  @override State<PrinterSetupPage> createState() => _PrinterSetupPageState();
}

class _PrinterSetupPageState extends State<PrinterSetupPage> {
  bool _isScanning = false, _enableAutoPrint = true;
  List<BluetoothDevice> _bondedDevices = [], _scannedDevices = [];
  BluetoothDevice? _selectedDevice;

  @override void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _enableAutoPrint = prefs.getBool('enable_auto_print') ?? true);
    final savedId = prefs.getString('selected_printer_id');
    if (savedId != null) {
      final devices = await FlutterBluePlus.bondedDevices;
      if (mounted) {
        try {
          setState(() => _selectedDevice = devices.firstWhere((d) => d.remoteId.toString() == savedId));
        } catch (_) {}
      }
    }
  }

  Future<void> _initPrinter() async {
    // Request permissions first using PermissionManager
    final granted = await Permission.bluetoothScan.status;
    if (!granted.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth permission required to find printers')),
      );
      return;
    }

    final devices = await FlutterBluePlus.bondedDevices;
    if (mounted) setState(() => _bondedDevices = devices);
  }

  Future<void> _scanForDevices() async {
    // Request Bluetooth permissions before scanning
    final scanStatus = await Permission.bluetoothScan.status;
    final connectStatus = await Permission.bluetoothConnect.status;
    final locationStatus = await Permission.location.status;

    if (!scanStatus.isGranted || !connectStatus.isGranted || !locationStatus.isGranted) {
      // Request all needed permissions
      await Permission.bluetooth.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      await Permission.location.request();

      // Check again after requesting
      final newScanStatus = await Permission.bluetoothScan.status;
      final newConnectStatus = await Permission.bluetoothConnect.status;
      final newLocationStatus = await Permission.location.status;

      if (!newScanStatus.isGranted || !newConnectStatus.isGranted || !newLocationStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bluetooth and Location permissions are required to scan for printers'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() { _isScanning = true; _scannedDevices.clear(); });
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((r) { if(mounted) setState(() => _scannedDevices = r.map((res) => res.device).toList()); });
    await Future.delayed(const Duration(seconds: 5)); await FlutterBluePlus.stopScan();
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _selectDevice(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_id', device.remoteId.toString());
    await prefs.setString('selected_printer_name', device.platformName);
    if (mounted) setState(() => _selectedDevice = device);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) { if (!didPop) widget.onBack(); },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
            title: const Text("Printer Setup", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            backgroundColor: kPrimaryColor,
            centerTitle: true, // Centered title
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
            actions: [IconButton(icon: Icon(_isScanning ? Icons.stop : Icons.refresh_rounded, color: Colors.white), onPressed: _isScanning ? FlutterBluePlus.stopScan : _scanForDevices)]
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_selectedDevice != null) Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.withOpacity(0.3))), child: Row(children: [const Icon(Icons.print_rounded, color: Colors.green, size: 30), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("CONNECTED PRINTER", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)), Text(_selectedDevice!.platformName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))])), IconButton(onPressed: () => setState(() => _selectedDevice = null), icon: const Icon(Icons.delete_outline_rounded, color: kErrorColor))])),

            Text("AVAILABLE DEVICES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1)),
            const SizedBox(height: 12),

            if (_bondedDevices.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorderColor),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No paired Bluetooth devices found', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _initPrinter,
                      icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
                      label: const Text('Find Printers', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)), child: Column(children: _bondedDevices.map((d) => ListTile(title: Text(d.platformName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text(d.remoteId.toString(), style: const TextStyle(fontSize: 11)), trailing: ElevatedButton(onPressed: () => _selectDevice(d), style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text("CONNECT", style: TextStyle(color: Colors.white, fontSize: 12))))).toList())),

            const SizedBox(height: 24),
            _SettingsGroup(children: [_SwitchTile("Auto Print Receipt", _enableAutoPrint, (v) async { (await SharedPreferences.getInstance()).setBool('enable_auto_print', v); setState(() => _enableAutoPrint = v); }, showDivider: false)]),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. RECEIPT SETTINGS PAGE
// ==========================================
class ReceiptSettingsPage extends StatelessWidget {
  final VoidCallback onBack; final Function(String) onNavigate; final String uid; final String? userEmail;
  const ReceiptSettingsPage({super.key, required this.onBack, required this.onNavigate, required this.uid, this.userEmail});
  @override Widget build(BuildContext context) => PopScope(canPop: false, onPopInvoked: (bool didPop) { if (!didPop) onBack(); }, child: Scaffold(backgroundColor: kGreyBg, appBar: AppBar(title: const Text("Receipts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: kPrimaryColor, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack)), body: ListView(padding: const EdgeInsets.all(16), children: [_SettingsGroup(children: [_SettingsTile(title: "Thermal Printer", subtitle: "58mm & 80mm Setup", icon: Icons.print_rounded, onTap: () => onNavigate('PrinterSetup')), _SettingsTile(title: "A4 Invoice / PDF", subtitle: "Customize layout", icon: Icons.picture_as_pdf_rounded, showDivider: false, onTap: () => onNavigate('ReceiptCustomization'))])])));
}

// ==========================================
// 6. RECEIPT CUSTOMIZATION PAGE
// ==========================================
class ReceiptCustomizationPage extends StatefulWidget {
  final VoidCallback onBack; const ReceiptCustomizationPage({super.key, required this.onBack});
  @override State<ReceiptCustomizationPage> createState() => _ReceiptCustomizationPageState();
}

class _ReceiptCustomizationPageState extends State<ReceiptCustomizationPage> {
  bool _showLogo = true, _showEmail = false, _showPhone = true, _showGST = true, _canUseLogo = false, _saving = false; int _selectedTemplateIndex = 0;
  @override void initState() { super.initState(); _loadSettings(); _checkLogoPermission(); }
  Future<void> _loadSettings() async { final prefs = await SharedPreferences.getInstance(); setState(() { _showLogo = prefs.getBool('receipt_show_logo') ?? true; _showEmail = prefs.getBool('receipt_show_email') ?? false; _showPhone = prefs.getBool('receipt_show_phone') ?? true; _showGST = prefs.getBool('receipt_show_gst') ?? true; _selectedTemplateIndex = prefs.getInt('invoice_template') ?? 0; }); }
  Future<void> _saveSettings() async { setState(() => _saving = true); final prefs = await SharedPreferences.getInstance(); await prefs.setBool('receipt_show_logo', _showLogo); await prefs.setBool('receipt_show_email', _showEmail); await prefs.setBool('receipt_show_phone', _showPhone); await prefs.setBool('receipt_show_gst', _showGST); await prefs.setInt('invoice_template', _selectedTemplateIndex); setState(() => _saving = false); widget.onBack(); }
  Future<void> _checkLogoPermission() async { final can = await PlanPermissionHelper.canUseLogoOnBill(); if (mounted) setState(() => _canUseLogo = can); }

  @override Widget build(BuildContext context) => PopScope(canPop: false, onPopInvoked: (bool didPop) { if (!didPop) widget.onBack(); }, child: Scaffold(backgroundColor: kGreyBg, appBar: AppBar(title: const Text("Customization", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: kPrimaryColor, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack)), body: ListView(padding: const EdgeInsets.all(16), children: [
    _buildCard("Choose Invoice Template", [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTemplateOption(0, "Classic Pro", "Standard layout", Icons.article_outlined, Colors.black),
            const SizedBox(height: 12),
            _buildTemplateOption(1, "Modern Blue", "Clean accents", Icons.receipt_long, kPrimaryColor),
            const SizedBox(height: 12),
            _buildTemplateOption(2, "Compact", "Space saver", Icons.description_outlined, Colors.blueGrey),
          ],
        ),
      )
    ]),
    const SizedBox(height: 16),
    _buildCard("Information Fields", [
      _SwitchTile("Show Logo", _showLogo, (v) { if(!_canUseLogo) { PlanPermissionHelper.showUpgradeDialog(context, 'Logo'); return; } setState(() => _showLogo = v); }, subtitle: _canUseLogo ? null : "Upgrade for business logo"),
      _SwitchTile("Show Email", _showEmail, (v) => setState(() => _showEmail = v)),
      _SwitchTile("Show Phone", _showPhone, (v) => setState(() => _showPhone = v)),
      _SwitchTile("Show GSTIN", _showGST, (v) => setState(() => _showGST = v), showDivider: false)
    ]),
    const SizedBox(height: 24),
    _PrimaryButton(text: _saving ? "Saving..." : "Save Preferences", onTap: _saveSettings)
  ])));

  Widget _buildTemplateOption(int index, String title, String desc, IconData icon, Color color) {
    final isSelected = _selectedTemplateIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTemplateIndex = index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.05) : Colors.white, border: Border.all(color: isSelected ? color : kBorderColor, width: isSelected ? 2 : 1), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : kTextPrimary)), Text(desc, style: const TextStyle(fontSize: 11, color: kTextSecondary))])),
          if (isSelected) Icon(Icons.check_circle_rounded, color: color, size: 20)
        ]),
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), const Divider(height: 1), ...children]));
}

// ==========================================
// 7. FEATURE SETTINGS PAGE
// ==========================================
class FeatureSettingsPage extends StatefulWidget {
  final VoidCallback onBack; const FeatureSettingsPage({super.key, required this.onBack});
  @override State<FeatureSettingsPage> createState() => _FeatureSettingsPageState();
}

class _FeatureSettingsPageState extends State<FeatureSettingsPage> {
  bool _enableAutoPrint = true, _blockOutOfStock = true; double _decimals = 2;
  @override Widget build(BuildContext context) => PopScope(canPop: false, onPopInvoked: (bool didPop) { if (!didPop) widget.onBack(); }, child: Scaffold(backgroundColor: kGreyBg, appBar: AppBar(title: const Text("Features", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: kPrimaryColor, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack)), body: ListView(padding: const EdgeInsets.all(16), children: [_SettingsGroup(children: [_SwitchTile("Auto Print Receipt", _enableAutoPrint, (v) => setState(() => _enableAutoPrint = v)), _SwitchTile("Block Out-of-Stock Sales", _blockOutOfStock, (v) => setState(() => _blockOutOfStock = v)), Padding(padding: const EdgeInsets.all(16), child: Column(children: [Row(children: [const Text("Decimal Precision", style: TextStyle(fontWeight: FontWeight.w500)), const Spacer(), Text(_decimals.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor))]), Slider(value: _decimals, min: 0, max: 4, divisions: 4, activeColor: kPrimaryColor, onChanged: (v) => setState(() => _decimals = v))]))])])));
}

// ==========================================
// 8. LANGUAGE PAGE
// ==========================================
class LanguagePage extends StatelessWidget {
  final VoidCallback onBack;
  const LanguagePage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LanguageProvider>(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (!didPop) onBack();
      },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                provider.translate('choose_language'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: kPrimaryColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack
          )
        ),
        body: Column(
          children: [
            // Info Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kOrange.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kOrange.withAlpha((0.3 * 255).toInt())),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: kOrange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Only English Available Now',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Other languages coming soon!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Language List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: provider.languages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  String code = provider.languages.keys.elementAt(i);
                  bool isSelected = provider.currentLanguageCode == code;
                  bool isEnglish = code == 'en';
                  bool isComingSoon = !isEnglish;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? kPrimaryColor : kBorderColor,
                        width: isSelected ? 1.5 : 1
                      )
                    ),
                    child: ListTile(
                      onTap: isComingSoon ? null : () => provider.changeLanguage(code),
                      enabled: !isComingSoon,
                      leading: CircleAvatar(
                        backgroundColor: isComingSoon ? kGreyBg : kGreyBg,
                        child: Text(
                          code.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isComingSoon ? kBlack54 : kTextSecondary
                          )
                        )
                      ),
                      title: Row(
                        children: [
                          Text(
                            provider.languages[code]!['name']!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isComingSoon ? kBlack54 : kBlack87,
                            )
                          ),
                          if (isComingSoon) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: kOrange.withAlpha((0.15 * 255).toInt()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Coming Soon',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: kOrange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: kPrimaryColor)
                        : (isComingSoon ? Icon(Icons.lock_outline, color: kBlack54, size: 20) : null)
                    )
                  );
                }
              ),
            ),
          ],
        )
      )
    );
  }
}

// ==========================================
// PLACEHOLDER & WIDGET HELPERS
// ==========================================
class ThemePage extends StatelessWidget { final VoidCallback onBack; const ThemePage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("Theme", onBack); }
class HelpPage extends StatelessWidget { final VoidCallback onBack; final Function(String) onNavigate; const HelpPage({super.key, required this.onBack, required this.onNavigate}); @override Widget build(BuildContext context) => _SimplePage("Help", onBack); }
class FAQsPage extends StatelessWidget { final VoidCallback onBack; const FAQsPage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("FAQs", onBack); }
class UpcomingFeaturesPage extends StatelessWidget { final VoidCallback onBack; const UpcomingFeaturesPage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("Features", onBack); }
class VideoTutorialsPage extends StatelessWidget { final VoidCallback onBack; const VideoTutorialsPage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("Videos", onBack); }

class _SimplePage extends StatelessWidget {
  final String title; final VoidCallback onBack; const _SimplePage(this.title, this.onBack);
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kGreyBg, appBar: AppBar(title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: kPrimaryColor, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack)), body: Center(child: Text("$title Content", style: const TextStyle(color: kBlack54))));
}

class _SettingsGroup extends StatelessWidget { final List<Widget> children; const _SettingsGroup({required this.children}); @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)), child: Column(children: children)); }

class _SettingsTile extends StatelessWidget {
  final IconData? icon; final String title; final String? subtitle; final VoidCallback onTap; final bool showDivider;
  const _SettingsTile({this.icon, required this.title, required this.onTap, this.showDivider = true, this.subtitle});
  @override Widget build(BuildContext context) => Column(children: [ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: kBlack87, size: 20)), title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: kBlack54)) : null, trailing: Icon(Icons.chevron_right_rounded, size: 20, color: kTextSecondary.withOpacity(0.5)), onTap: onTap), if (showDivider) const Divider(height: 1, indent: 60, color: kGrey100)]);
}

class _SwitchTile extends StatelessWidget {
  final String title; final bool value; final Function(bool) onChanged; final bool showDivider; final bool hasInfo; final String? subtitle;
  const _SwitchTile(this.title, this.value, this.onChanged, {this.showDivider = true, this.hasInfo = false, this.subtitle});
  @override Widget build(BuildContext context) => Column(children: [Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)), if (hasInfo) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.info_outline, size: 14, color: kBlack54))]), if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.bold))])), CupertinoSwitch(value: value, onChanged: onChanged, activeColor: kPrimaryColor)])), if (showDivider) const Divider(height: 1, indent: 16, color: kGrey100)]);
}

class _SimpleTextField extends StatelessWidget { final String hint; final int maxLines; const _SimpleTextField({required this.hint, this.maxLines = 1}); @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12)), child: TextField(maxLines: maxLines, decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: kBlack54, fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)))); }

class _PrimaryButton extends StatelessWidget {
  final String text; final VoidCallback onTap; const _PrimaryButton({required this.text, required this.onTap});
  @override Widget build(BuildContext context) => SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))));
}