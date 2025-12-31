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
import 'dart:async';
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
  StreamSubscription? _storeDataSub;

  @override
  void initState() {
    super.initState();
    _initFastFetch();
  }

  /// FAST FETCH: Using memory cache and reactive streams for 0ms load
  Future<void> _initFastFetch() async {
    final fs = FirestoreService();

    final storeDoc = await fs.getCurrentStoreDoc();
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get(
        const GetOptions(source: Source.cache)
    );

    if (mounted) {
      setState(() {
        _storeData = storeDoc?.data() as Map<String, dynamic>?;
        _userData = userDoc.data();
        _loading = false;
      });
      _handleImageCaching();
    }

    _storeDataSub = fs.storeDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _storeData = data;
        });
        _handleImageCaching();
      }
    });

    fs.notifyStoreDataChanged();
  }

  void _handleImageCaching() {
    final logoUrl = _storeData?['logoUrl'] as String?;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      precacheImage(NetworkImage(logoUrl), context);
    }
  }

  @override
  void dispose() {
    _storeDataSub?.cancel();
    super.dispose();
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

    if (_currentView != null) {
      switch (_currentView) {
        case 'BusinessDetails':
          return BusinessDetailsPage(
            uid: widget.uid,
            onBack: _goBack,
            initialStoreData: _storeData,
            initialUserData: _userData,
          );
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
        title: Text(context.tr('settings'), style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 24),
          _buildSectionTitle("App Config"),
          _buildModernTile(
            title: context.tr('business_details'),
            icon: Icons.store_mall_directory_rounded,
            color: const Color(0xFF1976D2),
            onTap: () => _navigateTo('BusinessDetails'),
            subtitle: "Manage business profile & currency",
          ),
          _buildModernTile(
            title: context.tr('receipt_customization'),
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFFF9800),
            onTap: () => _navigateTo('ReceiptSettings'),
            subtitle: "Invoice templates & format",
          ),
          _buildModernTile(
            title: context.tr('tax_settings'),
            icon: Icons.percent_rounded,
            color: const Color(0xFF43A047),
            onTap: () => _navigateTo('TaxSettings'),
            subtitle: "GST, VAT & local tax compliance",
          ),
          _buildModernTile(
            title: context.tr('printer_setup'),
            icon: Icons.print_rounded,
            color: const Color(0xFF9C27B0),
            onTap: () => _navigateTo('PrinterSetup'),
            subtitle: "Setup Bluetooth thermal printers",
          ),
          _buildModernTile(
            title: context.tr('language'),
            icon: Icons.language_rounded,
            color: const Color(0xFF12008C),
            onTap: () => _navigateTo('Language'),
            subtitle: "Choose your preferred language",
          ),
          const SizedBox(height: 32),
          const Center(child: Text('VERSION 1.0.0', style: TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))),
          const SizedBox(height: 16),
          _buildLogoutButton(),
          const SizedBox(height: 40),
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
    final name = _storeData?['businessName'] ?? _userData?['businessName'] ?? _userData?['name'] ?? 'Business Owner';
    final email = _userData?['email'] ?? widget.userEmail ?? '';
    final logoUrl = _storeData?['logoUrl'] ?? '';

    final planProvider = Provider.of<PlanProvider>(context);
    return FutureBuilder<String>(
      future: planProvider.getCurrentPlan(),
      builder: (context, snapshot) {
        final plan = snapshot.data ?? 'Free';
        final isPremium = plan.toLowerCase() != 'free' && plan.toLowerCase() != 'starter';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kGrey200),
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
                              child: Image.network(logoUrl, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: kGreyBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: kGrey200, width: 2),
                    image: logoUrl.isNotEmpty ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover) : null,
                  ),
                  child: logoUrl.isEmpty ? const Icon(Icons.store_rounded, size: 28, color: kGrey400) : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isPremium ? kGoogleGreen : kOrange).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: (isPremium ? kGoogleGreen : kOrange).withOpacity(0.2)),
                          ),
                          child: Text(plan.toUpperCase(), style: TextStyle(fontSize: 9, color: isPremium ? kGoogleGreen : kOrange, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                        if (!isPremium) ...[
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () async {
                              await Navigator.push(context, CupertinoPageRoute(builder: (context) => SubscriptionPlanPage(uid: widget.uid, currentPlan: plan)));
                              if (mounted) setState(() {});
                            },
                            child: const Text('UPGRADE NOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: 0.5)),
                          ),
                        ]
                      ],
                    ),
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
        color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGrey200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kBlack87)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: kBlack54, fontSize: 11, fontWeight: FontWeight.w500)) : null,
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: kGrey400, size: 14),
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
          side: const BorderSide(color: kErrorColor, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("SIGN OUT", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kErrorColor, letterSpacing: 1.0)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(title.toUpperCase(), style: const TextStyle(color: kBlack54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
  );
}

// ==========================================
// 2. BUSINESS DETAILS PAGE
// ==========================================
class BusinessDetailsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;
  final Map<String, dynamic>? initialStoreData;
  final Map<String, dynamic>? initialUserData;

  const BusinessDetailsPage({
    super.key,
    required this.uid,
    required this.onBack,
    this.initialStoreData,
    this.initialUserData,
  });

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
  String _selectedCurrency = 'INR';

  final List<Map<String, String>> _currencies = [
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'SAR', 'symbol': '﷼', 'name': 'Saudi Riyal'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialStoreData != null) {
      final data = widget.initialStoreData!;
      _nameCtrl.text = data['businessName'] ?? '';
      _phoneCtrl.text = data['businessPhone'] ?? '';
      _gstCtrl.text = data['gstin'] ?? '';
      _licenseCtrl.text = data['licenseNumber'] ?? '';
      _selectedCurrency = data['currency'] ?? 'INR';
      _locCtrl.text = data['businessLocation'] ?? '';
      _ownerCtrl.text = data['ownerName'] ?? '';
      _logoUrl = data['logoUrl'];
      _fetching = false;
    }
    if (widget.initialUserData != null) {
      _emailCtrl.text = widget.initialUserData!['email'] ?? '';
      if (_ownerCtrl.text.isEmpty) _ownerCtrl.text = widget.initialUserData!['name'] ?? '';
    }

    _loadData();
    _gstCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _gstCtrl.dispose(); _licenseCtrl.dispose(); _locCtrl.dispose(); _emailCtrl.dispose(); _ownerCtrl.dispose(); _locationFocusNode.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    try {
      final store = await FirestoreService().getCurrentStoreDoc();
      final user = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (store != null && store.exists) {
        final data = store.data() as Map<String, dynamic>;
        setState(() {
          _nameCtrl.text = data['businessName'] ?? '';
          _phoneCtrl.text = data['businessPhone'] ?? '';
          _gstCtrl.text = data['gstin'] ?? '';
          _licenseCtrl.text = data['licenseNumber'] ?? '';
          _selectedCurrency = data['currency'] ?? 'INR';
          _locCtrl.text = data['businessLocation'] ?? '';
          _ownerCtrl.text = data['ownerName'] ?? '';
          _logoUrl = data['logoUrl'];
          _fetching = false;
        });
      }
      if (user.exists) {
        final uData = user.data() as Map<String, dynamic>;
        setState(() => _emailCtrl.text = uData['email'] ?? '');
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Crop Logo', toolbarColor: kPrimaryColor, toolbarWidgetColor: kWhite, initAspectRatio: CropAspectRatioPreset.square, lockAspectRatio: true),
          IOSUiSettings(title: 'Crop Logo', aspectRatioLockEnabled: true),
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
      await FirebaseFirestore.instance.collection('store').doc(storeId).set({'logoUrl': downloadUrl}, SetOptions(merge: true));
      await FirestoreService().notifyStoreDataChanged();
      if (mounted) setState(() => _logoUrl = downloadUrl);
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
        await FirestoreService().notifyStoreDataChanged();
        if (mounted) setState(() => _editing = false);
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
          title: const Text("Business Profile", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: kPrimaryColor,
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: () => _editing ? setState(() => _editing = false) : widget.onBack()),
          actions: [
            if (!_fetching)
              _loading
                  ? const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: kWhite, strokeWidth: 2))
                  : IconButton(icon: Icon(_editing ? Icons.check_circle_rounded : Icons.edit_note_rounded, color: kWhite, size: 28), onPressed: () => _editing ? _save() : setState(() => _editing = true))
          ],
        ),
        body: _fetching ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Center(child: Stack(children: [
                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(color: kWhite, shape: BoxShape.circle, border: Border.all(color: kGrey200, width: 2)),
                    child: ClipOval(
                      child: _selectedImage != null
                          ? Image.file(_selectedImage!, fit: BoxFit.cover)
                          : _logoUrl != null && _logoUrl!.isNotEmpty
                          ? Image.network(_logoUrl!, fit: BoxFit.cover, key: ValueKey(_logoUrl))
                          : const Icon(Icons.add_business_rounded, size: 40, color: kGrey400),
                    ),
                  ),
                  if (_editing) Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: _uploadingImage ? null : _pickImage, child: Container(width: 34, height: 34, decoration: BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle, border: Border.all(color: kWhite, width: 2)), child: _uploadingImage ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Icon(Icons.camera_alt_rounded, color: kWhite, size: 16)))),
                ])),
                const SizedBox(height: 24),
                _buildSectionLabel("IDENTITY & TAX"),
                _buildModernField("Business Name", _nameCtrl, Icons.store_rounded, enabled: _editing, isMandatory: true),
                _buildLocationField(),
                _buildModernField("Tax/GST Number", _gstCtrl, Icons.receipt_long_rounded, enabled: _editing),
                _buildModernField("License Number", _licenseCtrl, Icons.badge_rounded, enabled: _editing),
                _buildCurrencyField(),
                const SizedBox(height: 24),
                _buildSectionLabel("CONTACT & OWNERSHIP"),
                _buildModernField("Owner Name", _ownerCtrl, Icons.person_rounded, enabled: _editing),
                _buildModernField("Phone Number", _phoneCtrl, Icons.phone_android_rounded, enabled: _editing, type: TextInputType.phone),
                _buildModernField("Email Address", _emailCtrl, Icons.email_rounded, enabled: false),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0))));

  Widget _buildModernField(String label, TextEditingController ctrl, IconData icon, {bool enabled = true, TextInputType type = TextInputType.text, bool isMandatory = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl, enabled: enabled, keyboardType: type,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: enabled ? kPrimaryColor : kGrey400, size: 18),
          filled: true, fillColor: enabled ? kWhite : kGreyBg.withOpacity(0.5),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
          floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800),
        ),
        validator: (v) => (isMandatory && (v == null || v.isEmpty)) ? "$label is required" : null,
      ),
    );
  }

  Widget _buildLocationField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AbsorbPointer(
        absorbing: !_editing,
        child: GooglePlaceAutoCompleteTextField(
          textEditingController: _locCtrl, focusNode: _locationFocusNode,
          googleAPIKey: "AIzaSyDXD9dhKhD6C8uB4ua9Nl04beav6qbtb3c",
          inputDecoration: InputDecoration(
            labelText: "Location", prefixIcon: const Icon(Icons.location_on_rounded, color: kPrimaryColor, size: 18),
            filled: true, fillColor: _editing ? kWhite : kGreyBg.withOpacity(0.5),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
            floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800),
          ),
          debounceTime: 600, countries: const ["in"], isLatLngRequired: false,
          itemClick: (p) { _locCtrl.text = p.description ?? ''; FocusScope.of(context).unfocus(); },
        ),
      ),
    );
  }

  Widget _buildCurrencyField() {
    final sel = _currencies.firstWhere((c) => c['code'] == _selectedCurrency, orElse: () => _currencies[0]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _editing ? _showCurrencyPicker : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _editing ? kWhite : kGreyBg.withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
          child: Row(
            children: [
              const Icon(Icons.currency_exchange_rounded, color: kPrimaryColor, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Business Currency", style: TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w800)), Text("${sel['symbol']} ${sel['code']} - ${sel['name']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87))])),
              if (_editing) const Icon(Icons.expand_more_rounded, color: kGrey400),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => Container(
      height: 400, padding: const EdgeInsets.all(20),
      child: Column(children: [
        const Text("Select Currency", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack87)),
        const SizedBox(height: 16),
        Expanded(child: ListView.separated(itemCount: _currencies.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (ctx, i) => ListTile(onTap: () { setState(() => _selectedCurrency = _currencies[i]['code']!); Navigator.pop(context); }, leading: Text(_currencies[i]['symbol']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryColor)), title: Text(_currencies[i]['name']!, style: const TextStyle(fontWeight: FontWeight.w600)), trailing: _selectedCurrency == _currencies[i]['code'] ? const Icon(Icons.check_circle, color: kPrimaryColor) : null))),
      ]),
    ));
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
  List<BluetoothDevice> _bondedDevices = [];
  BluetoothDevice? _selectedDevice;

  @override void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _enableAutoPrint = prefs.getBool('enable_auto_print') ?? true);
    final savedId = prefs.getString('selected_printer_id');
    if (savedId != null) {
      final devices = await FlutterBluePlus.bondedDevices;
      if (mounted) {
        try { setState(() => _selectedDevice = devices.firstWhere((d) => d.remoteId.toString() == savedId)); } catch (_) {}
      }
    }
  }

  Future<void> _scanForDevices() async {
    if (await Permission.bluetoothScan.request().isDenied) return;
    setState(() => _isScanning = true);
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((r) { if(mounted) setState(() {}); });
    await Future.delayed(const Duration(seconds: 4));
    await FlutterBluePlus.stopScan();
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _selectDevice(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_id', device.remoteId.toString());
    if (mounted) setState(() => _selectedDevice = device);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text("Printer Setup", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: kPrimaryColor, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_selectedDevice != null) Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGoogleGreen.withOpacity(0.3))), child: Row(children: [const Icon(Icons.print_rounded, color: kGoogleGreen, size: 28), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("ACTIVE PRINTER", style: TextStyle(fontSize: 9, color: kGoogleGreen, fontWeight: FontWeight.w900, letterSpacing: 0.5)), Text(_selectedDevice!.platformName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kBlack87))])), IconButton(onPressed: () => setState(() => _selectedDevice = null), icon: const Icon(Icons.delete_sweep_rounded, color: kErrorColor))])),
          Text("PAIRED DEVICES", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          _buildDeviceList(),
          const SizedBox(height: 24),
          _SettingsGroup(children: [_SwitchTile("Auto Print Receipt", _enableAutoPrint, (v) async { (await SharedPreferences.getInstance()).setBool('enable_auto_print', v); setState(() => _enableAutoPrint = v); }, showDivider: false)]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _isScanning ? null : _scanForDevices, backgroundColor: kPrimaryColor, icon: _isScanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Icon(Icons.bluetooth_searching_rounded), label: Text(_isScanning ? "SCANNING..." : "SCAN FOR PRINTERS", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
    );
  }

  Widget _buildDeviceList() {
    return FutureBuilder<List<BluetoothDevice>>(
      future: FlutterBluePlus.bondedDevices,
      builder: (ctx, snap) {
        final devices = snap.data ?? [];
        if (devices.isEmpty) return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)), child: const Center(child: Text("No paired devices found", style: TextStyle(color: kBlack54, fontSize: 13))));
        return Container(decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)), child: Column(children: devices.map((d) => ListTile(onTap: () => _selectDevice(d), leading: const Icon(Icons.print_outlined, color: kPrimaryColor), title: Text(d.platformName.isEmpty ? "Unknown Printer" : d.platformName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text(d.remoteId.toString(), style: const TextStyle(fontSize: 10)), trailing: const Icon(Icons.add_circle_outline_rounded, color: kPrimaryColor, size: 20))).toList()));
      },
    );
  }
}

// ==========================================
// 4. FEATURE SETTINGS PAGE
// ==========================================
class FeatureSettingsPage extends StatefulWidget {
  final VoidCallback onBack;
  const FeatureSettingsPage({super.key, required this.onBack});
  @override State<FeatureSettingsPage> createState() => _FeatureSettingsPageState();
}

class _FeatureSettingsPageState extends State<FeatureSettingsPage> {
  bool _enableAutoPrint = true, _blockOutOfStock = true; double _decimals = 2;
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kGreyBg, appBar: AppBar(title: const Text("Features", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)), backgroundColor: kPrimaryColor, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack)), body: ListView(padding: const EdgeInsets.all(16), children: [_SettingsGroup(children: [_SwitchTile("Auto Print Receipt", _enableAutoPrint, (v) => setState(() => _enableAutoPrint = v)), _SwitchTile("Block Out-of-Stock Sales", _blockOutOfStock, (v) => setState(() => _blockOutOfStock = v)), Padding(padding: const EdgeInsets.all(16), child: Column(children: [Row(children: [const Text("Decimal Precision", style: TextStyle(fontWeight: FontWeight.w700)), const Spacer(), Text(_decimals.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor))]), Slider(value: _decimals, min: 0, max: 4, divisions: 4, activeColor: kPrimaryColor, onChanged: (v) => setState(() => _decimals = v))]))])]));
}

// ==========================================
// SHARED UI HELPERS (ENTERPRISE FLAT)
// ==========================================
class ReceiptSettingsPage extends StatelessWidget {
  final VoidCallback onBack; final Function(String) onNavigate; final String uid; final String? userEmail;
  const ReceiptSettingsPage({super.key, required this.onBack, required this.onNavigate, required this.uid, this.userEmail});
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kGreyBg, appBar: AppBar(title: const Text("Receipts", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: kPrimaryColor, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: onBack)), body: ListView(padding: const EdgeInsets.all(16), children: [_SettingsGroup(children: [_SettingsTile(title: "Bluetooth Thermal Printer", subtitle: "Connect 58mm & 80mm printers", icon: Icons.print_rounded, onTap: () => onNavigate('PrinterSetup')), _SettingsTile(title: "Invoice Customization", subtitle: "PDF & Template layout settings", icon: Icons.palette_rounded, showDivider: false, onTap: () => onNavigate('ReceiptCustomization'))])]));
}

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

  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kGreyBg, appBar: AppBar(title: const Text("Invoice Style", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: kPrimaryColor, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack)), body: ListView(padding: const EdgeInsets.all(16), children: [
    _buildSectionLabel("TEMPLATE STYLE"),
    _buildTemplateGrid(),
    const SizedBox(height: 24),
    _buildSectionLabel("VISIBILITY TOGGLES"),
    _SettingsGroup(children: [
      _SwitchTile("Show Business Logo", _showLogo, (v) { if(!_canUseLogo) { PlanPermissionHelper.showUpgradeDialog(context, 'Logo'); return; } setState(() => _showLogo = v); }, subtitle: _canUseLogo ? null : "Requires Premium Plan"),
      _SwitchTile("Show Contact Email", _showEmail, (v) => setState(() => _showEmail = v)),
      _SwitchTile("Show Contact Phone", _showPhone, (v) => setState(() => _showPhone = v)),
      _SwitchTile("Show Tax Number (GST)", _showGST, (v) => setState(() => _showGST = v), showDivider: false)
    ]),
    const SizedBox(height: 32),
    _PrimaryButton(text: _saving ? "SAVING..." : "APPLY CHANGES", onTap: _saveSettings)
  ]));

  Widget _buildTemplateGrid() {
    return Column(children: [
      _templateTile(0, "Classic Professional", "Standard business layout", Icons.article_rounded, kBlack87),
      const SizedBox(height: 12),
      _templateTile(1, "Modern Dynamic", "Clean with blue accents", Icons.receipt_long_rounded, kPrimaryColor),
      const SizedBox(height: 12),
      _templateTile(2, "Compact Receipt", "Optimized for minimal space", Icons.description_rounded, Colors.blueGrey),
    ]);
  }

  Widget _templateTile(int idx, String title, String desc, IconData icon, Color color) {
    bool sel = _selectedTemplateIndex == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedTemplateIndex = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: sel ? kPrimaryColor : kGrey200, width: sel ? 2 : 1)),
        child: Row(children: [Icon(icon, color: sel ? kPrimaryColor : kBlack54, size: 24), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: sel ? kPrimaryColor : kBlack87)), Text(desc, style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w500))])), if (sel) const Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 20)]),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0)));
}

class LanguagePage extends StatelessWidget {
  final VoidCallback onBack;
  const LanguagePage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text("Select Language", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16)), centerTitle: true, backgroundColor: kPrimaryColor, leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: onBack)),
      body: Column(
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16), margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kOrange.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: kOrange.withOpacity(0.2))),
            child: Row(children: [const Icon(Icons.info_outline_rounded, color: kOrange, size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('English is fully supported', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kOrange)), Text('Localized support for other languages is in progress.', style: TextStyle(fontSize: 11, color: kBlack87, fontWeight: FontWeight.w500))]))]),
          ),
          Expanded(
            child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: provider.languages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  String code = provider.languages.keys.elementAt(i);
                  bool sel = provider.currentLanguageCode == code;
                  bool soon = code != 'en';
                  return Container(
                    decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: sel ? kPrimaryColor : kGrey200, width: sel ? 1.5 : 1)),
                    child: ListTile(
                      onTap: soon ? null : () => provider.changeLanguage(code),
                      leading: CircleAvatar(backgroundColor: kGreyBg, child: Text(code.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kBlack54))),
                      title: Row(children: [Text(provider.languages[code]!['name']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), if (soon) Container(margin: const EdgeInsets.only(left: 10), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(6)), child: const Text("SOON", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: kBlack54)))]),
                      trailing: sel ? const Icon(Icons.check_circle_rounded, color: kPrimaryColor) : (soon ? const Icon(Icons.lock_clock_rounded, size: 16, color: kGrey400) : null),
                    ),
                  );
                }
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget { final List<Widget> children; const _SettingsGroup({required this.children}); @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGrey200)), child: Column(children: children)); }
class _SettingsTile extends StatelessWidget {
  final IconData? icon; final String title; final String? subtitle; final VoidCallback onTap; final bool showDivider;
  const _SettingsTile({this.icon, required this.title, required this.onTap, this.showDivider = true, this.subtitle});
  @override Widget build(BuildContext context) => Column(children: [ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: kBlack87, size: 20)), title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w500)) : null, trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kGrey400), onTap: onTap), if (showDivider) const Divider(height: 1, indent: 60, color: kGrey100)]);
}
class _SwitchTile extends StatelessWidget {
  final String title; final bool value; final Function(bool) onChanged; final bool showDivider; final String? subtitle; final bool enabled;
  const _SwitchTile(this.title, this.value, this.onChanged, {this.showDivider = true, this.subtitle, this.enabled = true});
  @override Widget build(BuildContext context) => Column(children: [Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 11, color: kOrange, fontWeight: FontWeight.w800))])), CupertinoSwitch(value: value, onChanged: enabled ? onChanged : null, activeColor: kPrimaryColor)])), if (showDivider) const Divider(height: 1, indent: 16, color: kGrey100)]);
}
class _PrimaryButton extends StatelessWidget {
  final String text; final VoidCallback onTap; const _PrimaryButton({required this.text, required this.onTap});
  @override Widget build(BuildContext context) => SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: Text(text, style: const TextStyle(color: kWhite, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.0))));
}

class ThemePage extends StatelessWidget { final VoidCallback onBack; const ThemePage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("Theme", onBack); }
class HelpPage extends StatelessWidget { final VoidCallback onBack; final Function(String) onNavigate; const HelpPage({super.key, required this.onBack, required this.onNavigate}); @override Widget build(BuildContext context) => _SimplePage("Help & Support", onBack); }
class FAQsPage extends StatelessWidget { final VoidCallback onBack; const FAQsPage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("Frequently Asked Questions", onBack); }
class UpcomingFeaturesPage extends StatelessWidget { final VoidCallback onBack; const UpcomingFeaturesPage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("New Features", onBack); }
class VideoTutorialsPage extends StatelessWidget { final VoidCallback onBack; const VideoTutorialsPage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("Tutorial Videos", onBack); }
class _SimplePage extends StatelessWidget {
  final String title; final VoidCallback onBack; const _SimplePage(this.title, this.onBack);
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kGreyBg, appBar: AppBar(title: Text(title, style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: kPrimaryColor, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: onBack)), body: Center(child: Text("$title Content Loading...", style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600))));
}