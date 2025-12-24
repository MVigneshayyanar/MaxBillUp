import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:google_places_flutter/google_places_flutter.dart';

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
// CONSTANTS & STYLES (MATCHED TO REPORT UI)
// ==========================================
const Color kPrimaryColor = Color(0xFF2F7CF6);
final Color kBgColor = const Color(0xFFF9FAFC);// Unified White Background
const Color kSurfaceColor = Colors.white;      // Card/Container White
const Color kInputFillColor = Color(0xFFF0F8FF); // Light Blue Tint
const Color kDangerColor = Color(0xFFFF3B30);
const Color kTextPrimary = Color(0xFF1D1D1D);
const Color kTextSecondary = Color(0xFF8A8A8E);
final Color kBorderColor = Color(0xFFE3F2FD);
// Feature Colors for Settings Icons
const Color kColorBusiness = Color(0xFF1976D2);
const Color kColorReceipt = Color(0xFFFF9800);
const Color kColorTax = Color(0xFF43A047);
const Color kColorPrinter = Color(0xFF9C27B0);
const Color kColorFeatures = Color(0xFF00897B);
const Color kColorLanguage = Color(0xFF3949AB);
const Color kColorHelp = Color(0xFFE91E63);
const Color kColorMarket = Color(0xFFFF5722);
const Color kColorRefer = Color(0xFF00ACC1);

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
          return TaxSettingsNew.TaxSettingsPage(uid: widget.uid); // Using imported TaxSettings
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

    // Main Settings List
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
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
            title: context.tr('feature_settings'),
            icon: Icons.tune_rounded,
            color: kColorFeatures,
            onTap: () => _navigateTo('FeatureSettings'),
            subtitle: "App preferences",
          ),
          _buildModernTile(
            title: context.tr('choose_language'),
            icon: Icons.language_rounded,
            color: kColorLanguage,
            onTap: () => _navigateTo('Language'),
            subtitle: "Change app language",
          ),

          const SizedBox(height: 24),
          _buildSectionTitle(context.tr('help')),
          _buildModernTile(
            title: context.tr('help'),
            icon: Icons.help_outline_rounded,
            color: kColorHelp,
            onTap: () => _navigateTo('Help'),
            subtitle: "FAQs & Support",
          ),
          _buildModernTile(
            title: "Market Place",
            icon: Icons.storefront_rounded,
            color: kColorMarket,
            onTap: () {},
            subtitle: "Explore addons",
          ),
          _buildModernTile(
            title: "Refer A Friend",
            icon: Icons.share_rounded,
            color: kColorRefer,
            onTap: () {},
            subtitle: "Invite & Earn",
          ),

          const SizedBox(height: 24),
          const Center(child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12))),
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

    // Use FutureBuilder to always fetch fresh plan data from Firestore
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
              CircleAvatar(
                radius: 28,
                backgroundColor: kPrimaryColor.withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "U",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor, fontSize: 20),
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
                    if (plan != 'Max') ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => SubscriptionPlanPage(
                                uid: widget.uid,
                                currentPlan: plan,
                              ),
                            ),
                          );
                          // Trigger rebuild to fetch fresh data
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

  Widget _buildModernTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withOpacity(0.1),
          highlightColor: color.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kTextPrimary)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: kTextSecondary.withOpacity(0.5), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          FirestoreService().clearCache();
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(CupertinoPageRoute(builder: (_) => const LoginPage()), (r) => false);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: kDangerColor,
          elevation: 0,
          side: const BorderSide(color: kDangerColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(title.toUpperCase(), style: const TextStyle(color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
  );

  String _formatExpiry(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

// ==========================================
// 2. BUSINESS DETAILS PAGE (REFACTORED)
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

  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // Read-only usually
  final _ownerCtrl = TextEditingController();
  final _locationFocusNode = FocusNode();

  bool _editing = false;
  bool _loading = false;
  bool _fetching = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _gstCtrl.dispose();
    _locCtrl.dispose();
    _emailCtrl.dispose();
    _ownerCtrl.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _fetching = true);
    try {
      final store = await FirestoreService().getCurrentStoreDoc();
      final user = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();

      if (store != null && store.exists) {
        final data = store.data() as Map<String, dynamic>;
        _nameCtrl.text = data['businessName'] ?? '';
        _phoneCtrl.text = data['businessPhone'] ?? '';
        _gstCtrl.text = data['gstin'] ?? '';
        _locCtrl.text = data['businessLocation'] ?? '';
        _ownerCtrl.text = data['ownerName'] ?? '';
      }

      if (user.exists) {
        final uData = user.data() as Map<String, dynamic>;
        _emailCtrl.text = uData['email'] ?? '';
        // If owner name not in store, try getting from user profile
        if (_ownerCtrl.text.isEmpty) {
          _ownerCtrl.text = uData['name'] ?? '';
        }
      }
    } catch (e) {
      debugPrint("Error loading business details: $e");
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId != null) {
        // Use set with merge to create or update the document
        await FirebaseFirestore.instance.collection('store').doc(storeId).set({
          'businessName': _nameCtrl.text.trim(),
          'businessPhone': _phoneCtrl.text.trim(),
          'gstin': _gstCtrl.text.trim(),
          'businessLocation': _locCtrl.text.trim(),
          'ownerName': _ownerCtrl.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Also update user profile - use set with merge to avoid not-found error
        await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
          'name': _ownerCtrl.text.trim(),
          'businessLocation': _locCtrl.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile updated successfully"), backgroundColor: Colors.green)
          );
          setState(() => _editing = false);
        }
      } else {
        throw Exception("Store configuration not found");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save: $e"), backgroundColor: kDangerColor)
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Business Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _editing ? () => setState(() => _editing = false) : widget.onBack
        ),
        actions: [
          if (!_fetching)
            IconButton(
              icon: Icon(_editing ? Icons.check : Icons.edit, color: Colors.white),
              onPressed: () {
                if (_editing) {
                  _save();
                } else {
                  setState(() => _editing = true);
                }
              },
            )
        ],
      ),
      body: _fetching
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
            child: Form(
              key: _formKey,
              child: Column(
                children: [

                  // Business Info Section
                  _buildSectionHeader("Business Information"),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorderColor)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _buildModernField("Business Name", _nameCtrl, Icons.store, enabled: _editing),
                        const Divider(height: 1, indent: 48),
                        _buildLocationField(),
                        const Divider(height: 1, indent: 48),
                        _buildModernField("GSTIN", _gstCtrl, Icons.receipt_long, enabled: _editing, hint: "Optional"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Contact Info Section
                  _buildSectionHeader("Contact Details"),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorderColor)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _buildModernField("Owner Name", _ownerCtrl, Icons.person, enabled: _editing),
                        const Divider(height: 1, indent: 48),
                        _buildModernField("Phone Number", _phoneCtrl, Icons.phone, enabled: _editing, type: TextInputType.phone),
                        const Divider(height: 1, indent: 48),
                        _buildModernField("Email Address", _emailCtrl, Icons.email, enabled: false, hint: "Read-only"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildModernField(String label, TextEditingController ctrl, IconData icon, {bool enabled = true, TextInputType type = TextInputType.text, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: ctrl,
        enabled: enabled,
        keyboardType: type,
        style: TextStyle(fontWeight: FontWeight.w600, color: enabled ? kTextPrimary : Colors.grey[600]),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
          hintText: hint,
          prefixIcon: Icon(icon, color: enabled ? kPrimaryColor : Colors.grey[400], size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          isDense: true,
        ),
        validator: (val) {
          if (enabled && label != "GSTIN" && (val == null || val.trim().isEmpty)) {
            return "$label is required";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildLocationField() {
    if (!_editing) {
      // When not editing, show as regular text field
      return _buildModernField("Location", _locCtrl, Icons.location_on, enabled: false);
    }

    // When editing, show Google Places autocomplete
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GooglePlaceAutoCompleteTextField(
        textEditingController: _locCtrl,
        focusNode: _locationFocusNode,
        googleAPIKey: "AIzaSyDXD9dhKhD6C8uB4ua9Nl04beav6qbtb3c",
        inputDecoration: InputDecoration(
          labelText: "Location",
          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
          hintText: "Search for business location",
          prefixIcon: Icon(Icons.location_on, color: kPrimaryColor, size: 22),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
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
            borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        debounceTime: 600,
        countries: const ["in"], // Focus on India for better suggestions
        isLatLngRequired: false,
        getPlaceDetailWithLatLng: (prediction) {
          _locCtrl.text = prediction.description ?? '';
          // Close keyboard after selection
          FocusScope.of(context).unfocus();
        },
        itemClick: (prediction) {
          _locCtrl.text = prediction.description ?? '';
          _locCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _locCtrl.text.length),
          );
          // Close keyboard after selection
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}

// ==========================================
// 4. PRINTER SETUP PAGE
// ==========================================
class PrinterSetupPage extends StatefulWidget {
  final VoidCallback onBack;
  const PrinterSetupPage({super.key, required this.onBack});
  @override
  State<PrinterSetupPage> createState() => _PrinterSetupPageState();
}

class _PrinterSetupPageState extends State<PrinterSetupPage> {
  bool _loading = false;
  bool _isScanning = false;
  List<BluetoothDevice> _bondedDevices = [];
  List<BluetoothDevice> _scannedDevices = [];
  BluetoothDevice? _selectedDevice;
  bool _enableAutoPrint = true;

  @override
  void initState() {
    super.initState();
    _initPrinter();
    _loadSettings();
  }

  // ... (Keep existing logic for printer init/scan methods same as your input) ...
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enableAutoPrint = prefs.getBool('enable_auto_print') ?? true;
    final savedDeviceId = prefs.getString('selected_printer_id');
    setState(() {
      _enableAutoPrint = enableAutoPrint;
    });
    if (savedDeviceId != null) _findSavedDevice(savedDeviceId);
  }

  Future<void> _findSavedDevice(String deviceId) async {
    try {
      final devices = await FlutterBluePlus.bondedDevices;
      final device = devices.firstWhere((d) => d.remoteId.toString() == deviceId, orElse: () => devices.first);
      if (mounted) setState(() => _selectedDevice = device);
    } catch (e) {}
  }

  Future<void> _initPrinter() async {
    if (await Permission.bluetoothScan.request().isGranted) _getBondedDevices();
  }

  Future<void> _getBondedDevices() async {
    setState(() => _loading = true);
    try {
      final devices = await FlutterBluePlus.bondedDevices;
      if (mounted) setState(() { _bondedDevices = devices; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanForDevices() async {
    setState(() { _isScanning = true; _scannedDevices.clear(); });
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      FlutterBluePlus.scanResults.listen((results) {
        if(mounted) setState(() => _scannedDevices = results.map((r) => r.device).toList());
      });
      await Future.delayed(const Duration(seconds: 5));
      await FlutterBluePlus.stopScan();
      if (mounted) setState(() => _isScanning = false);
    } catch (e) {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _selectDevice(BluetoothDevice device) async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_id', device.remoteId.toString());
    await prefs.setString('selected_printer_name', device.platformName);
    if (mounted) {
      setState(() { _selectedDevice = device; _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Printer selected"), backgroundColor: Colors.green));
    }
  }

  Future<void> _removeDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_printer_id');
    if (mounted) setState(() => _selectedDevice = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Printer Setup", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
        actions: [
          IconButton(icon: Icon(_isScanning ? Icons.stop : Icons.refresh, color: Colors.white), onPressed: _isScanning ? FlutterBluePlus.stopScan : _scanForDevices),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_selectedDevice != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
              child: Row(
                children: [
                  const Icon(Icons.print_rounded, color: Colors.green, size: 32),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Connected Printer", style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_selectedDevice!.platformName.isNotEmpty ? _selectedDevice!.platformName : "Unknown Device", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(_selectedDevice!.remoteId.toString(), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ])),
                  IconButton(onPressed: _removeDevice, icon: const Icon(Icons.delete_outline, color: Colors.red)),
                ],
              ),
            ),

          _buildSectionTitle("Available Devices"),
          const SizedBox(height: 8),

          if (_loading || _isScanning) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: kPrimaryColor))),

          if (!_loading && !_isScanning && _bondedDevices.isEmpty && _scannedDevices.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              alignment: Alignment.center,
              child: Column(
                children: const [
                  Icon(Icons.bluetooth_disabled_rounded, size: 48, color: kTextSecondary),
                  SizedBox(height: 12),
                  Text("No devices found", style: TextStyle(color: kTextSecondary)),
                ],
              ),
            ),

          if (_bondedDevices.isNotEmpty || _scannedDevices.isNotEmpty)
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.05), blurRadius: 4)]),
              child: Column(
                children: [
                  ..._bondedDevices.map((d) => _buildDeviceTile(d, true)),
                  ..._scannedDevices.where((d) => !_bondedDevices.any((b) => b.remoteId == d.remoteId)).map((d) => _buildDeviceTile(d, false)),
                ],
              ),
            ),

          const SizedBox(height: 24),
          _SettingsGroup(children: [
            _SwitchTile("Enable Auto Print", _enableAutoPrint, (v) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('enable_auto_print', v);
              setState(() => _enableAutoPrint = v);
            }, hasInfo: true),
          ]),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(BluetoothDevice device, bool isPaired) {
    bool isSelected = _selectedDevice?.remoteId == device.remoteId;
    return ListTile(
      leading: Icon(Icons.print, color: isSelected ? kPrimaryColor : kTextSecondary),
      title: Text(device.platformName.isNotEmpty ? device.platformName : "Unknown Device"),
      subtitle: Text(device.remoteId.toString(), style: const TextStyle(color: kTextSecondary)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: kPrimaryColor) : ElevatedButton(
        onPressed: () => _selectDevice(device),
        style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: const Text("Connect", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title.toUpperCase(), style: const TextStyle(color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.bold));
}

// ==========================================
// OTHER SETTINGS PAGES
// ==========================================
class ReceiptSettingsPage extends StatelessWidget {
  final VoidCallback onBack;
  final Function(String) onNavigate;
  final String uid;
  final String? userEmail;

  const ReceiptSettingsPage({super.key, required this.onBack, required this.onNavigate, required this.uid, this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(title: const Text("Receipt Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: kPrimaryColor, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsGroup(children: [
            _SettingsTile(title: "Thermal Printer", subtitle: "58mm & 80mm Setup", icon: Icons.print_rounded, showDivider: true, onTap: () => onNavigate('PrinterSetup')),
            _SettingsTile(title: "A4 Invoice / PDF", subtitle: "Customize layout & fields", icon: Icons.picture_as_pdf_rounded, showDivider: false, onTap: () => onNavigate('ReceiptCustomization')),
          ]),
        ],
      ),
    );
  }
}

class ReceiptCustomizationPage extends StatefulWidget {
  final VoidCallback onBack;
  const ReceiptCustomizationPage({super.key, required this.onBack});
  @override
  State<ReceiptCustomizationPage> createState() => _ReceiptCustomizationPageState();
}

class _ReceiptCustomizationPageState extends State<ReceiptCustomizationPage> {
  bool _showLogo = true;
  bool _showEmail = false;
  bool _showPhone = true;
  bool _showGST = true;
  bool _canUseLogo = false;

  @override
  void initState() {
    super.initState();
    _checkLogoPermission();
  }

  Future<void> _checkLogoPermission() async {
    final canUseLogo = await PlanPermissionHelper.canUseLogoOnBill();
    if (mounted) {
      setState(() {
        _canUseLogo = canUseLogo;
        // If user can't use logo, disable it
        if (!_canUseLogo) {
          _showLogo = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(title: const Text("Customize Invoice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: kPrimaryColor, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard("Header Information", [
            _SwitchTile(
              "Show Logo",
              _showLogo,
              (v) {
                if (!_canUseLogo) {
                  PlanPermissionHelper.showUpgradeDialog(context, 'Logo on Bill');
                  return;
                }
                setState(() => _showLogo = v);
              },
              subtitle: _canUseLogo ? null : "Upgrade to use logo",
            ),
            _SwitchTile("Show Email", _showEmail, (v) => setState(() => _showEmail = v)),
            _SwitchTile("Show Phone", _showPhone, (v) => setState(() => _showPhone = v)),
            _SwitchTile("Show GSTIN", _showGST, (v) => setState(() => _showGST = v), showDivider: false),
          ]),
          const SizedBox(height: 16),
          _buildCard("Footer & Notes", [
            Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text("Terms & Conditions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 8),
              _SimpleTextField(hint: "e.g. No refunds after 7 days...", maxLines: 3),
              SizedBox(height: 16),
              Text("Footer Note", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 8),
              _SimpleTextField(hint: "Thank you for shopping with us!"),
            ])),
          ]),
          const SizedBox(height: 24),
          _PrimaryButton(text: "Save Preferences", onTap: widget.onBack),
        ],
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.05), blurRadius: 4)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        const Divider(height: 1),
        ...children,
      ]),
    );
  }
}

class TaxSettingsPage extends StatefulWidget {
  final VoidCallback onBack;
  const TaxSettingsPage({super.key, required this.onBack});
  @override
  State<TaxSettingsPage> createState() => _TaxSettingsPageState();
}

class _TaxSettingsPageState extends State<TaxSettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _taxes = [{'val': 5.0, 'name': 'GST', 'active': true}, {'val': 12.0, 'name': 'GST', 'active': false}, {'val': 18.0, 'name': 'GST', 'active': true}];

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(title: const Text("Tax Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: kPrimaryColor, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack)),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: kInputFillColor, borderRadius: BorderRadius.circular(8)),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(8)),
                labelColor: Colors.white, unselectedLabelColor: kTextSecondary, indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent,
                tabs: const [Tab(text: "Manage Taxes"), Tab(text: "Defaults")],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ListView(padding: const EdgeInsets.all(16), children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Add New Tax Rate", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(flex: 2, child: _SimpleTextField(hint: "Name (e.g. VAT)")),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: _SimpleTextField(hint: "%")),
                        const SizedBox(width: 12),
                        ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)), child: const Text("Add", style: TextStyle(color: Colors.white))),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Active Tax Rates"),
                  const SizedBox(height: 8),
                  _SettingsGroup(children: _taxes.map((t) => _buildTaxTile(t)).toList()),
                ]),
                ListView(padding: const EdgeInsets.all(16), children: [Center(child: Text("Default settings coming soon", style: TextStyle(color: kTextSecondary)))]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxTile(Map tax) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: kPrimaryColor.withOpacity(0.1), child: Text("${tax['val']}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryColor))),
      title: Text(tax['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Switch(value: tax['active'], onChanged: (v) => setState(() => tax['active'] = v), activeColor: kPrimaryColor),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title.toUpperCase(), style: const TextStyle(color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.bold));
}

class FeatureSettingsPage extends StatefulWidget {
  final VoidCallback onBack;
  const FeatureSettingsPage({super.key, required this.onBack});
  @override
  State<FeatureSettingsPage> createState() => _FeatureSettingsPageState();
}

class _FeatureSettingsPageState extends State<FeatureSettingsPage> {
  bool _enableAutoPrint = true;
  bool _blockOutOfStock = true;
  double _decimals = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(title: const Text("Features", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: kPrimaryColor, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _SettingsGroup(children: [
          _SwitchTile("Auto Print Receipt", _enableAutoPrint, (v) => setState(() => _enableAutoPrint = v), hasInfo: true),
          _SwitchTile("Block Out-of-Stock Sales", _blockOutOfStock, (v) => setState(() => _blockOutOfStock = v), hasInfo: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(children: [
              Row(children: [const Text("Decimal Precision", style: TextStyle(fontWeight: FontWeight.w500)), const Spacer(), Text(_decimals.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor))]),
              Slider(value: _decimals, min: 0, max: 4, divisions: 4, activeColor: kPrimaryColor, onChanged: (v) => setState(() => _decimals = v)),
            ]),
          )
        ]),
      ]),
    );
  }
}

class LanguagePage extends StatelessWidget {
  final VoidCallback onBack;
  const LanguagePage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(title: Text(provider.translate('choose_language'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: kPrimaryColor, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: provider.languages.length,
        separatorBuilder: (c,i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          String code = provider.languages.keys.elementAt(index);
          var lang = provider.languages[code]!;
          bool isSelected = provider.currentLanguageCode == code;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? kPrimaryColor : Colors.transparent, width: 2),
              boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.05), blurRadius: 4)],
            ),
            child: ListTile(
              onTap: () => provider.changeLanguage(code),
              leading: CircleAvatar(backgroundColor: kInputFillColor, child: Text(code.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary))),
              title: Text(lang['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(lang['native']!, style: const TextStyle(color: kTextSecondary)),
              trailing: isSelected ? const Icon(Icons.check_circle, color: kPrimaryColor) : null,
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// PLACEHOLDER PAGES
// ==========================================
class ThemePage extends StatelessWidget { final VoidCallback onBack; const ThemePage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("Theme", onBack); }
class HelpPage extends StatelessWidget { final VoidCallback onBack; final Function(String) onNavigate; const HelpPage({super.key, required this.onBack, required this.onNavigate}); @override Widget build(BuildContext context) => _SimplePage("Help", onBack); }
class FAQsPage extends StatelessWidget { final VoidCallback onBack; const FAQsPage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("FAQs", onBack); }
class UpcomingFeaturesPage extends StatelessWidget { final VoidCallback onBack; const UpcomingFeaturesPage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("Features", onBack); }
class VideoTutorialsPage extends StatelessWidget { final VoidCallback onBack; const VideoTutorialsPage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("Videos", onBack); }

class _SimplePage extends StatelessWidget {
  final String title; final VoidCallback onBack;
  const _SimplePage(this.title, this.onBack);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: kPrimaryColor, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack)),
      body: Center(child: Text("$title Content", style: const TextStyle(color: kTextSecondary))),
    );
  }
}

// ==========================================
// HELPER WIDGETS
// ==========================================
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: kPrimaryColor.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showDivider;
  const _SettingsTile({this.icon, required this.title, required this.onTap, this.showDivider = true, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: icon != null ? Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kInputFillColor, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.black87, size: 20)) : null,
          title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: kTextSecondary)) : null,
          trailing: const Icon(Icons.chevron_right, size: 20, color: kTextSecondary),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        if (showDivider) const Divider(height: 1, thickness: 0.5, indent: 60, endIndent: 0, color: Color(0xFFE3F2FD)),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final Function(bool) onChanged;
  final bool showDivider;
  final bool hasInfo;
  final String? subtitle;
  const _SwitchTile(this.title, this.value, this.onChanged, {this.showDivider = true, this.hasInfo = false, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        if (hasInfo) ...[const SizedBox(width: 6), const Icon(Icons.info_outline, size: 16, color: kTextSecondary)],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
                    ],
                  ],
                ),
              ),
              CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: kPrimaryColor),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 16, color: Color(0xFFE3F2FD)),
      ],
    );
  }
}

class _SimpleTextField extends StatelessWidget {
  final String hint;
  final int maxLines;
  const _SimpleTextField({required this.hint, this.maxLines = 1});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: kInputFillColor, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }
}

class _SimpleDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  const _SimpleDropdown({required this.value, required this.items});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: kInputFillColor, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {},
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _PrimaryButton({required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          shadowColor: kPrimaryColor.withOpacity(0.3),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}