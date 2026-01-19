import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:maxbillup/services/number_generator_service.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/Sales/components/common_widgets.dart';
import 'package:maxbillup/utils/language_provider.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_permission_helper.dart';
import 'package:maxbillup/Settings/TaxSettings.dart' as TaxSettingsNew;

// ==========================================DF
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

  // Permission tracking
  Map<String, dynamic> _permissions = {};
  String _role = '';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initFastFetch();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _permissions = data['permissions'] as Map<String, dynamic>? ?? {};
          _role = data['role'] as String? ?? '';
          _isAdmin = _role.toLowerCase() == 'owner' || _role.toLowerCase() == 'administrator' || _role.toLowerCase() == 'owner';
        });
      } else {
        // If no user doc found, check if this is the store owner
        final storeDoc = await FirestoreService().getCurrentStoreDoc();
        if (storeDoc != null && mounted) {
          final storeData = storeDoc.data() as Map<String, dynamic>?;
          if (storeData?['ownerId'] == widget.uid) {
            setState(() {
              _isAdmin = true;
              _role = 'Owner';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading permissions: $e');
    }
  }

  bool _hasPermission(String permission) {
    if (_isAdmin) return true;
    return _permissions[permission] == true;
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
      // Wrap sub-pages with PopScope to handle Android back button
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _goBack();
          }
        },
        child: _buildSubPage(),
      );
    }

    return _buildMainSettingsPage(context, screenWidth);
  }

  Widget _buildSubPage() {
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
        return TaxSettingsNew.TaxSettingsPage(uid: widget.uid, onBack: _goBack);
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
      default:
        return _buildMainSettingsPage(context, MediaQuery.of(context).size.width);
    }
  }

  Widget _buildMainSettingsPage(BuildContext context, double screenWidth) {
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
          // Business Details - only visible if admin or has editBusinessProfile permission
          if (_isAdmin || _hasPermission('editBusinessProfile'))
            _buildModernTile(
              title: context.tr('business_details'),
              icon: Icons.store_mall_directory_rounded,
              color: const Color(0xFF1976D2),
              onTap: () => _navigateTo('BusinessDetails'),
              subtitle: "Manage business profile & currency",
            ),
          // Receipt Customization - only visible if admin or has receiptCustomization permission
          if (_isAdmin || _hasPermission('receiptCustomization'))
            _buildModernTile(
              title: context.tr('receipt_customization'),
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFFF9800),
              onTap: () => _navigateTo('ReceiptCustomization'),
              subtitle: "Invoice templates & format",
            ),
          // Tax Settings - only visible if admin or has taxSettings permission
          if (_isAdmin || _hasPermission('taxSettings'))
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subscription info bar
          // Main bottom navigation
          CommonBottomNav(
            uid: widget.uid,
            userEmail: widget.userEmail,
            currentIndex: 4,
            screenWidth: screenWidth,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final name = _storeData?['businessName'] ?? _userData?['businessName'] ?? _userData?['name'] ?? 'Business Owner';
    final email = _userData?['email'] ?? widget.userEmail ?? '';
    final logoUrl = _storeData?['logoUrl'] ?? '';

    // Use Consumer to automatically rebuild when plan changes
    return Consumer<PlanProvider>(
      builder: (context, planProvider, child) {
        // Use cached plan for instant access - updates automatically when subscription changes
        final plan = planProvider.cachedPlan;
        final isPremium = plan.toLowerCase() != 'free' && plan.toLowerCase() != 'starter';
        final expiryDate = planProvider.cachedExpiryDate;
        final isExpiringSoon = planProvider.isExpiringSoon;
        final daysUntilExpiry = planProvider.daysUntilExpiry;

        // Format expiry date
        String? expiryText;
        if (isPremium && expiryDate != null) {
          final day = expiryDate.day.toString().padLeft(2, '0');
          final month = _getMonthName(expiryDate.month);
          final year = expiryDate.year;
          expiryText = '$day $month $year';
        }

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
                    // Plan badge - clickable to go to subscription page
                    GestureDetector(
                      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => SubscriptionPlanPage(uid: widget.uid, currentPlan: plan))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                const Text('UPGRADE NOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: 0.5)),
                              ]
                            ],
                          ),
                          // Expiry date - show if premium plan
                          if (isPremium && expiryText != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.event_rounded, size: 12, color: isExpiringSoon ? kErrorColor : kBlack54),
                                const SizedBox(width: 4),
                                Text(
                                  isExpiringSoon
                                    ? 'Expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'} ($expiryText)'
                                    : 'Valid till $expiryText',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isExpiringSoon ? kErrorColor : kBlack54,
                                    fontWeight: isExpiringSoon ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                                if (isExpiringSoon) ...[
                                  const SizedBox(width: 6),
                                  const Text('RENEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kPrimaryColor)),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
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

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kBlack87)),
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
  final _nameCtrl = TextEditingController(), _phoneCtrl = TextEditingController(), _locCtrl = TextEditingController(), _emailCtrl = TextEditingController(), _ownerCtrl = TextEditingController();
  final _taxTypeCtrl = TextEditingController(), _taxNumberCtrl = TextEditingController();
  final _licenseTypeCtrl = TextEditingController(), _licenseNumberCtrl = TextEditingController();
  final _locationFocusNode = FocusNode();
  bool _editing = false, _loading = false, _fetching = true, _uploadingImage = false;

  // Individual field edit states
  Map<String, bool> _fieldEditStates = {
    'businessName': false,
    'location': false,
    'taxType': false,
    'taxNumber': false,
    'licenseType': false,
    'licenseNumber': false,
    'currency': false,
    'ownerName': false,
    'phoneNumber': false,
  };

  String? _logoUrl;
  File? _selectedImage;
  String _selectedCurrency = 'INR';

  final List<Map<String, String>> _currencies = [
    // Popular currencies first
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},

    // Asia-Pacific
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'AFN', 'symbol': '؋', 'name': 'Afghan Afghani'},
    {'code': 'AMD', 'symbol': '֏', 'name': 'Armenian Dram'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'AZN', 'symbol': '₼', 'name': 'Azerbaijani Manat'},
    {'code': 'BDT', 'symbol': '৳', 'name': 'Bangladeshi Taka'},
    {'code': 'BHD', 'symbol': '.د.ب', 'name': 'Bahraini Dinar'},
    {'code': 'BND', 'symbol': 'B\$', 'name': 'Brunei Dollar'},
    {'code': 'BTN', 'symbol': 'Nu.', 'name': 'Bhutanese Ngultrum'},
    {'code': 'FJD', 'symbol': 'FJ\$', 'name': 'Fijian Dollar'},
    {'code': 'GEL', 'symbol': '₾', 'name': 'Georgian Lari'},
    {'code': 'HKD', 'symbol': 'HK\$', 'name': 'Hong Kong Dollar'},
    {'code': 'IDR', 'symbol': 'Rp', 'name': 'Indonesian Rupiah'},
    {'code': 'ILS', 'symbol': '₪', 'name': 'Israeli New Shekel'},
    {'code': 'IQD', 'symbol': 'ع.د', 'name': 'Iraqi Dinar'},
    {'code': 'IRR', 'symbol': '﷼', 'name': 'Iranian Rial'},
    {'code': 'JOD', 'symbol': 'د.ا', 'name': 'Jordanian Dinar'},
    {'code': 'KHR', 'symbol': '៛', 'name': 'Cambodian Riel'},
    {'code': 'KRW', 'symbol': '₩', 'name': 'South Korean Won'},
    {'code': 'KWD', 'symbol': 'د.ك', 'name': 'Kuwaiti Dinar'},
    {'code': 'KZT', 'symbol': '₸', 'name': 'Kazakhstani Tenge'},
    {'code': 'LAK', 'symbol': '₭', 'name': 'Lao Kip'},
    {'code': 'LBP', 'symbol': 'ل.ل', 'name': 'Lebanese Pound'},
    {'code': 'LKR', 'symbol': 'Rs', 'name': 'Sri Lankan Rupee'},
    {'code': 'MMK', 'symbol': 'K', 'name': 'Myanmar Kyat'},
    {'code': 'MNT', 'symbol': '₮', 'name': 'Mongolian Tugrik'},
    {'code': 'MOP', 'symbol': 'MOP\$', 'name': 'Macanese Pataca'},
    {'code': 'MVR', 'symbol': 'Rf', 'name': 'Maldivian Rufiyaa'},
    {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit'},
    {'code': 'NPR', 'symbol': 'Rs', 'name': 'Nepalese Rupee'},
    {'code': 'NZD', 'symbol': 'NZ\$', 'name': 'New Zealand Dollar'},
    {'code': 'OMR', 'symbol': 'ر.ع.', 'name': 'Omani Rial'},
    {'code': 'PHP', 'symbol': '₱', 'name': 'Philippine Peso'},
    {'code': 'PKR', 'symbol': 'Rs', 'name': 'Pakistani Rupee'},
    {'code': 'QAR', 'symbol': 'ر.ق', 'name': 'Qatari Riyal'},
    {'code': 'SAR', 'symbol': '﷼', 'name': 'Saudi Riyal'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
    {'code': 'SYP', 'symbol': '£S', 'name': 'Syrian Pound'},
    {'code': 'THB', 'symbol': '฿', 'name': 'Thai Baht'},
    {'code': 'TJS', 'symbol': 'ЅМ', 'name': 'Tajikistani Somoni'},
    {'code': 'TMT', 'symbol': 'm', 'name': 'Turkmenistani Manat'},
    {'code': 'TRY', 'symbol': '₺', 'name': 'Turkish Lira'},
    {'code': 'TWD', 'symbol': 'NT\$', 'name': 'New Taiwan Dollar'},
    {'code': 'UZS', 'symbol': 'so\'m', 'name': 'Uzbekistani Som'},
    {'code': 'VND', 'symbol': '₫', 'name': 'Vietnamese Dong'},
    {'code': 'YER', 'symbol': '﷼', 'name': 'Yemeni Rial'},

    // Americas
    {'code': 'ARS', 'symbol': '\$', 'name': 'Argentine Peso'},
    {'code': 'AWG', 'symbol': 'ƒ', 'name': 'Aruban Florin'},
    {'code': 'BBD', 'symbol': 'Bds\$', 'name': 'Barbadian Dollar'},
    {'code': 'BMD', 'symbol': 'BD\$', 'name': 'Bermudian Dollar'},
    {'code': 'BOB', 'symbol': 'Bs.', 'name': 'Bolivian Boliviano'},
    {'code': 'BRL', 'symbol': 'R\$', 'name': 'Brazilian Real'},
    {'code': 'BSD', 'symbol': 'B\$', 'name': 'Bahamian Dollar'},
    {'code': 'BZD', 'symbol': 'BZ\$', 'name': 'Belize Dollar'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    {'code': 'CLP', 'symbol': '\$', 'name': 'Chilean Peso'},
    {'code': 'COP', 'symbol': '\$', 'name': 'Colombian Peso'},
    {'code': 'CRC', 'symbol': '₡', 'name': 'Costa Rican Colón'},
    {'code': 'CUP', 'symbol': '\$', 'name': 'Cuban Peso'},
    {'code': 'DOP', 'symbol': 'RD\$', 'name': 'Dominican Peso'},
    {'code': 'GTQ', 'symbol': 'Q', 'name': 'Guatemalan Quetzal'},
    {'code': 'GYD', 'symbol': 'G\$', 'name': 'Guyanese Dollar'},
    {'code': 'HNL', 'symbol': 'L', 'name': 'Honduran Lempira'},
    {'code': 'HTG', 'symbol': 'G', 'name': 'Haitian Gourde'},
    {'code': 'JMD', 'symbol': 'J\$', 'name': 'Jamaican Dollar'},
    {'code': 'KYD', 'symbol': 'CI\$', 'name': 'Cayman Islands Dollar'},
    {'code': 'MXN', 'symbol': '\$', 'name': 'Mexican Peso'},
    {'code': 'NIO', 'symbol': 'C\$', 'name': 'Nicaraguan Córdoba'},
    {'code': 'PAB', 'symbol': 'B/.', 'name': 'Panamanian Balboa'},
    {'code': 'PEN', 'symbol': 'S/.', 'name': 'Peruvian Sol'},
    {'code': 'PYG', 'symbol': '₲', 'name': 'Paraguayan Guaraní'},
    {'code': 'SRD', 'symbol': '\$', 'name': 'Surinamese Dollar'},
    {'code': 'TTD', 'symbol': 'TT\$', 'name': 'Trinidad and Tobago Dollar'},
    {'code': 'UYU', 'symbol': '\$U', 'name': 'Uruguayan Peso'},
    {'code': 'VES', 'symbol': 'Bs.S', 'name': 'Venezuelan Bolívar'},
    {'code': 'XCD', 'symbol': 'EC\$', 'name': 'East Caribbean Dollar'},

    // Europe
    {'code': 'ALL', 'symbol': 'L', 'name': 'Albanian Lek'},
    {'code': 'BAM', 'symbol': 'KM', 'name': 'Bosnia and Herzegovina Mark'},
    {'code': 'BGN', 'symbol': 'лв', 'name': 'Bulgarian Lev'},
    {'code': 'BYN', 'symbol': 'Br', 'name': 'Belarusian Ruble'},
    {'code': 'CHF', 'symbol': 'CHF', 'name': 'Swiss Franc'},
    {'code': 'CZK', 'symbol': 'Kč', 'name': 'Czech Koruna'},
    {'code': 'DKK', 'symbol': 'kr', 'name': 'Danish Krone'},
    {'code': 'GIP', 'symbol': '£', 'name': 'Gibraltar Pound'},
    {'code': 'HRK', 'symbol': 'kn', 'name': 'Croatian Kuna'},
    {'code': 'HUF', 'symbol': 'Ft', 'name': 'Hungarian Forint'},
    {'code': 'ISK', 'symbol': 'kr', 'name': 'Icelandic Króna'},
    {'code': 'MDL', 'symbol': 'L', 'name': 'Moldovan Leu'},
    {'code': 'MKD', 'symbol': 'ден', 'name': 'Macedonian Denar'},
    {'code': 'NOK', 'symbol': 'kr', 'name': 'Norwegian Krone'},
    {'code': 'PLN', 'symbol': 'zł', 'name': 'Polish Złoty'},
    {'code': 'RON', 'symbol': 'lei', 'name': 'Romanian Leu'},
    {'code': 'RSD', 'symbol': 'дин', 'name': 'Serbian Dinar'},
    {'code': 'RUB', 'symbol': '₽', 'name': 'Russian Ruble'},
    {'code': 'SEK', 'symbol': 'kr', 'name': 'Swedish Krona'},
    {'code': 'UAH', 'symbol': '₴', 'name': 'Ukrainian Hryvnia'},

    // Africa
    {'code': 'AOA', 'symbol': 'Kz', 'name': 'Angolan Kwanza'},
    {'code': 'BWP', 'symbol': 'P', 'name': 'Botswana Pula'},
    {'code': 'CDF', 'symbol': 'FC', 'name': 'Congolese Franc'},
    {'code': 'DJF', 'symbol': 'Fdj', 'name': 'Djiboutian Franc'},
    {'code': 'DZD', 'symbol': 'د.ج', 'name': 'Algerian Dinar'},
    {'code': 'EGP', 'symbol': '£', 'name': 'Egyptian Pound'},
    {'code': 'ERN', 'symbol': 'Nfk', 'name': 'Eritrean Nakfa'},
    {'code': 'ETB', 'symbol': 'Br', 'name': 'Ethiopian Birr'},
    {'code': 'GHS', 'symbol': '₵', 'name': 'Ghanaian Cedi'},
    {'code': 'GMD', 'symbol': 'D', 'name': 'Gambian Dalasi'},
    {'code': 'GNF', 'symbol': 'FG', 'name': 'Guinean Franc'},
    {'code': 'KES', 'symbol': 'KSh', 'name': 'Kenyan Shilling'},
    {'code': 'LRD', 'symbol': 'L\$', 'name': 'Liberian Dollar'},
    {'code': 'LSL', 'symbol': 'L', 'name': 'Lesotho Loti'},
    {'code': 'LYD', 'symbol': 'ل.د', 'name': 'Libyan Dinar'},
    {'code': 'MAD', 'symbol': 'د.م.', 'name': 'Moroccan Dirham'},
    {'code': 'MGA', 'symbol': 'Ar', 'name': 'Malagasy Ariary'},
    {'code': 'MRU', 'symbol': 'UM', 'name': 'Mauritanian Ouguiya'},
    {'code': 'MUR', 'symbol': '₨', 'name': 'Mauritian Rupee'},
    {'code': 'MWK', 'symbol': 'MK', 'name': 'Malawian Kwacha'},
    {'code': 'MZN', 'symbol': 'MT', 'name': 'Mozambican Metical'},
    {'code': 'NAD', 'symbol': 'N\$', 'name': 'Namibian Dollar'},
    {'code': 'NGN', 'symbol': '₦', 'name': 'Nigerian Naira'},
    {'code': 'RWF', 'symbol': 'FRw', 'name': 'Rwandan Franc'},
    {'code': 'SCR', 'symbol': '₨', 'name': 'Seychellois Rupee'},
    {'code': 'SDG', 'symbol': 'ج.س.', 'name': 'Sudanese Pound'},
    {'code': 'SLL', 'symbol': 'Le', 'name': 'Sierra Leonean Leone'},
    {'code': 'SOS', 'symbol': 'Sh', 'name': 'Somali Shilling'},
    {'code': 'SSP', 'symbol': '£', 'name': 'South Sudanese Pound'},
    {'code': 'SZL', 'symbol': 'L', 'name': 'Swazi Lilangeni'},
    {'code': 'TND', 'symbol': 'د.ت', 'name': 'Tunisian Dinar'},
    {'code': 'TZS', 'symbol': 'TSh', 'name': 'Tanzanian Shilling'},
    {'code': 'UGX', 'symbol': 'USh', 'name': 'Ugandan Shilling'},
    {'code': 'XAF', 'symbol': 'FCFA', 'name': 'Central African CFA Franc'},
    {'code': 'XOF', 'symbol': 'CFA', 'name': 'West African CFA Franc'},
    {'code': 'ZAR', 'symbol': 'R', 'name': 'South African Rand'},
    {'code': 'ZMW', 'symbol': 'ZK', 'name': 'Zambian Kwacha'},
    {'code': 'ZWL', 'symbol': 'Z\$', 'name': 'Zimbabwean Dollar'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialStoreData != null) {
      final data = widget.initialStoreData!;
      _nameCtrl.text = data['businessName'] ?? '';
      _phoneCtrl.text = data['businessPhone'] ?? '';

      // Split taxType into type and number (format: "Type Number")
      final taxType = data['taxType'] ?? data['gstin'] ?? '';
      if (taxType.isNotEmpty) {
        final taxParts = taxType.toString().split(' ');
        if (taxParts.length > 1) {
          _taxTypeCtrl.text = taxParts[0];
          _taxNumberCtrl.text = taxParts.sublist(1).join(' ');
        } else {
          _taxTypeCtrl.text = '';
          _taxNumberCtrl.text = taxType;
        }
      }

      // Split licenseNumber into type and number (format: "Type Number")
      final licenseNumber = data['licenseNumber'] ?? '';
      if (licenseNumber.isNotEmpty) {
        final licenseParts = licenseNumber.toString().split(' ');
        if (licenseParts.length > 1) {
          _licenseTypeCtrl.text = licenseParts[0];
          _licenseNumberCtrl.text = licenseParts.sublist(1).join(' ');
        } else {
          _licenseTypeCtrl.text = '';
          _licenseNumberCtrl.text = licenseNumber;
        }
      }

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
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _taxTypeCtrl.dispose(); _taxNumberCtrl.dispose(); _licenseTypeCtrl.dispose(); _licenseNumberCtrl.dispose(); _locCtrl.dispose(); _emailCtrl.dispose(); _ownerCtrl.dispose(); _locationFocusNode.dispose(); super.dispose(); }


  /// Handle FAB press - enables all fields or saves all edited fields
  // dart
  // Add/replace these members inside `_BusinessDetailsPageState`

  void _handleFabPress() {
    final bool isAnyFieldEditing = _fieldEditStates.values.any((v) => v == true);

    if (isAnyFieldEditing) {
      // User clicked "Save"
      _saveAllFields();
    } else {
      // Enable editing for all editable fields
      setState(() {
        _editing = true;
        _fieldEditStates.updateAll((key, value) => true);
      });
    }
  }

  Future<void> _saveAllFields() async {
    // Basic form validation (if you use _formKey around fields)
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      CommonWidgets.showSnackBar(context, 'Please fix validation errors', bgColor: const Color(0xFFFF5252));
      return;
    }

    setState(() => _loading = true);

    try {
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId == null) throw Exception('Store ID not found');

      // Build update payload (trimmed values)
      final updateData = <String, dynamic>{
        'businessName': _nameCtrl.text.trim(),
        'businessPhone': _phoneCtrl.text.trim(),
        'businessLocation': _locCtrl.text.trim(),
        'ownerName': _ownerCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'currency': _selectedCurrency,
        // Combine tax/license fields if present
        'taxType': (_taxTypeCtrl.text.trim().isNotEmpty && _taxNumberCtrl.text.trim().isNotEmpty)
            ? '${_taxTypeCtrl.text.trim()} ${_taxNumberCtrl.text.trim()}'
            : (_taxNumberCtrl.text.trim().isNotEmpty ? _taxNumberCtrl.text.trim() : _taxTypeCtrl.text.trim()),
        'licenseNumber': (_licenseTypeCtrl.text.trim().isNotEmpty && _licenseNumberCtrl.text.trim().isNotEmpty)
            ? '${_licenseTypeCtrl.text.trim()} ${_licenseNumberCtrl.text.trim()}'
            : (_licenseNumberCtrl.text.trim().isNotEmpty ? _licenseNumberCtrl.text.trim() : _licenseTypeCtrl.text.trim()),
      };

      await FirebaseFirestore.instance.collection('store').doc(storeId).set(updateData, SetOptions(merge: true));
      await FirestoreService().notifyStoreDataChanged();

      // Disable all edit states on success
      if (mounted) {
        setState(() {
          _editing = false;
          _fieldEditStates.updateAll((key, value) => false);
        });
      }

      CommonWidgets.showSnackBar(context, 'All changes saved successfully!', bgColor: const Color(0xFF4CAF50));
    } catch (e) {
      CommonWidgets.showSnackBar(context, 'Error saving: ${e.toString()}', bgColor: const Color(0xFFFF5252));
      debugPrint('BusinessDetailsPage save error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Replace / ensure the Scaffold's floatingActionButton uses this snippet:


  Future<void> _loadData() async {
    try {
      final store = await FirestoreService().getCurrentStoreDoc();
      final user = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (store != null && store.exists) {
        final data = store.data() as Map<String, dynamic>;
        setState(() {
          _nameCtrl.text = data['businessName'] ?? '';
          _phoneCtrl.text = data['businessPhone'] ?? '';

          // Split taxType into type and number (format: "Type Number")
          final taxType = data['taxType'] ?? data['gstin'] ?? '';
          if (taxType.isNotEmpty) {
            final taxParts = taxType.toString().split(' ');
            if (taxParts.length > 1) {
              _taxTypeCtrl.text = taxParts[0];
              _taxNumberCtrl.text = taxParts.sublist(1).join(' ');
            } else {
              _taxTypeCtrl.text = '';
              _taxNumberCtrl.text = taxType;
            }
          }

          // Split licenseNumber into type and number (format: "Type Number")
          final licenseNumber = data['licenseNumber'] ?? '';
          if (licenseNumber.isNotEmpty) {
            final licenseParts = licenseNumber.toString().split(' ');
            if (licenseParts.length > 1) {
              _licenseTypeCtrl.text = licenseParts[0];
              _licenseNumberCtrl.text = licenseParts.sublist(1).join(' ');
            } else {
              _licenseTypeCtrl.text = '';
              _licenseNumberCtrl.text = licenseNumber;
            }
          }

          _selectedCurrency = data['currency'] ?? 'INR';
          _locCtrl.text = data['businessLocation'] ?? '';
          _ownerCtrl.text = data['ownerName'] ?? '';
          _logoUrl = data['logoUrl'];
          // Load email from store, fallback to user email
          if (data['email'] != null && data['email'].toString().isNotEmpty) {
            _emailCtrl.text = data['email'];
          }
          _fetching = false;
        });
      }
      if (user.exists) {
        final uData = user.data() as Map<String, dynamic>;
        // Only set email from user if not already set from store
        if (_emailCtrl.text.isEmpty) {
          setState(() => _emailCtrl.text = uData['email'] ?? '');
        }
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
          AndroidUiSettings(
            toolbarTitle: 'Crop Logo',
            toolbarColor: kPrimaryColor,
            toolbarWidgetColor: kWhite,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square, // Only square option
            ],
          ),
          IOSUiSettings(
            title: 'Crop Logo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square, // Only square option
            ],
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
        // Combine tax type and number into single field
        final taxType = '${_taxTypeCtrl.text.trim()} ${_taxNumberCtrl.text.trim()}'.trim();
        // Combine license type and number into single field
        final licenseNumber = '${_licenseTypeCtrl.text.trim()} ${_licenseNumberCtrl.text.trim()}'.trim();

        await FirebaseFirestore.instance.collection('store').doc(storeId).set({
          'businessName': _nameCtrl.text.trim(),
          'businessPhone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'taxType': taxType,
          'gstin': taxType,
          'licenseNumber': licenseNumber,
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
    // Check if any field is in edit mode
    final bool isAnyFieldEditing = _fieldEditStates.values.any((isEditing) => isEditing == true);

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) { if (!didPop) { widget.onBack(); } },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
          title: const Text("Business Profile", style: TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: kPrimaryColor,
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: () => widget.onBack()),
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
                  Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: _uploadingImage ? null : _pickImage, child: Container(width: 34, height: 34, decoration: BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle, border: Border.all(color: kWhite, width: 2)), child: _uploadingImage ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Icon(Icons.camera_alt_rounded, color: kWhite, size: 16)))),
                ])),
                const SizedBox(height: 24),
                _buildSectionLabel("IDENTITY & TAX"),
                _buildModernField("Business Name", _nameCtrl, Icons.store_rounded, isMandatory: true, fieldKey: 'businessName'),
                _buildLocationField(),
                _buildModernFieldWithHint("Tax Type", _taxTypeCtrl, Icons.receipt_long_rounded, hint: "VAT, GST, Sales Tax", fieldKey: 'taxType'),
                _buildModernFieldWithHint("Tax Number", _taxNumberCtrl, Icons.numbers_rounded, hint: "Enter your tax identification number", fieldKey: 'taxNumber'),
                _buildModernFieldWithHint("License Type", _licenseTypeCtrl, Icons.badge_rounded, hint: "Business License, Trade License", fieldKey: 'licenseType'),
                _buildModernFieldWithHint("License Number", _licenseNumberCtrl, Icons.numbers_rounded, hint: "Enter your license number", fieldKey: 'licenseNumber'),
                _buildCurrencyField(),
                const SizedBox(height: 24),
                _buildSectionLabel("CONTACT & OWNERSHIP"),
                _buildModernField("Owner Name", _ownerCtrl, Icons.person_rounded, fieldKey: 'ownerName'),
                _buildModernField("Phone Number", _phoneCtrl, Icons.phone_android_rounded, type: TextInputType.phone, fieldKey: 'phoneNumber'),
                _buildModernField("Email Address", _emailCtrl, Icons.email_rounded, enabled: false, showEditIcon: false),
                const SizedBox(height: 80), // Extra padding for FAB
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _handleFabPress,
          backgroundColor: kPrimaryColor,
          icon: Icon(
            _fieldEditStates.values.any((v) => v)
                ? Icons.save_rounded
                : Icons.edit_rounded,
            color: kWhite,
          ),
          label: Text(
            _fieldEditStates.values.any((v) => v) ? 'SAVE' : 'EDIT',
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0))));

  Widget _buildModernField(String label, TextEditingController ctrl, IconData icon, {bool enabled = true, TextInputType type = TextInputType.text, bool isMandatory = false, String? fieldKey, bool showEditIcon = true}) {
    final hasValue = ctrl.text.isNotEmpty;
    final isEditing = fieldKey != null && (_fieldEditStates[fieldKey] ?? false);

    // Use enabled parameter for fields that should never be editable (like email)
    final isFieldEnabled = enabled;
    final isReadOnly = !isEditing || !enabled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        enabled: isFieldEnabled,
        readOnly: isReadOnly,
        keyboardType: type,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: !isReadOnly ? kPrimaryColor : kGrey400, size: 18),
          filled: true,
          fillColor: !isReadOnly ? kWhite : kGreyBg.withOpacity(0.5),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasValue ? kPrimaryColor : kGrey200, width: hasValue ? 1.5 : 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasValue ? kPrimaryColor.withOpacity(0.5) : kGrey200)),
          floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800),
        ),
        validator: (v) => (isMandatory && (v == null || v.isEmpty)) ? "$label is required" : null,
      ),
    );
  }

  Widget _buildModernFieldWithHint(String label, TextEditingController ctrl, IconData icon, {bool enabled = true, TextInputType type = TextInputType.text, bool isMandatory = false, String? hint, String? fieldKey, bool showEditIcon = true}) {
    final hasValue = ctrl.text.isNotEmpty;
    final isEditing = fieldKey != null && (_fieldEditStates[fieldKey] ?? false);

    // Use enabled parameter for fields that should never be editable
    final isFieldEnabled = enabled;
    final isReadOnly = !isEditing || !enabled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        enabled: isFieldEnabled,
        readOnly: isReadOnly,
        keyboardType: type,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: kGrey400, fontWeight: FontWeight.w400),
          prefixIcon: Icon(icon, color: !isReadOnly ? kPrimaryColor : kGrey400, size: 18),
          filled: true,
          fillColor: !isReadOnly ? kWhite : kGreyBg.withOpacity(0.5),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasValue ? kPrimaryColor : kGrey200, width: hasValue ? 1.5 : 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasValue ? kPrimaryColor.withOpacity(0.5) : kGrey200)),
          floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800),
        ),
        validator: (v) => (isMandatory && (v == null || v.isEmpty)) ? "$label is required" : null,
      ),
    );
  }

  Widget _buildDualFieldRow(String label1, TextEditingController ctrl1, String label2, TextEditingController ctrl2, IconData icon) {
    final hasValue1 = ctrl1.text.isNotEmpty;
    final hasValue2 = ctrl2.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Type field (smaller, with icon)
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: ctrl1,
              enabled: _editing,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
              decoration: InputDecoration(
                labelText: label1,
                prefixIcon: Icon(icon, color: _editing ? kPrimaryColor : kGrey400, size: 18),
                filled: true,
                fillColor: _editing ? kWhite : kGreyBg.withOpacity(0.5),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasValue1 ? kPrimaryColor : kGrey200, width: hasValue1 ? 1.5 : 1)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
                disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasValue1 ? kPrimaryColor.withOpacity(0.5) : kGrey200)),
                floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Number field (larger, no icon)
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: ctrl2,
              enabled: _editing,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
              decoration: InputDecoration(
                labelText: label2,
                filled: true,
                fillColor: _editing ? kWhite : kGreyBg.withOpacity(0.5),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasValue2 ? kPrimaryColor : kGrey200, width: hasValue2 ? 1.5 : 1)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
                disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasValue2 ? kPrimaryColor.withOpacity(0.5) : kGrey200)),
                floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField() {
    final hasValue = _locCtrl.text.isNotEmpty;
    final isEditing = _fieldEditStates['location'] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _locCtrl,
        focusNode: _locationFocusNode,
        readOnly: !isEditing,
        decoration: InputDecoration(
          labelText: "Location",
          prefixIcon: Icon(
            Icons.location_on_rounded,
            color: isEditing ? kPrimaryColor : kGrey400,
            size: 18,
          ),
          filled: true,
          fillColor: isEditing ? kWhite : kGreyBg.withOpacity(0.5),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: hasValue ? kPrimaryColor : kGrey200, width: hasValue ? 1.5 : 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: kPrimaryColor,
              width: 1.5,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: hasValue ? kPrimaryColor.withOpacity(0.5) : kGrey200),
          ),
          floatingLabelStyle: const TextStyle(
            color: kPrimaryColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }


  Widget _buildCurrencyField() {
    final sel = _currencies.firstWhere((c) => c['code'] == _selectedCurrency, orElse: () => _currencies[0]);
    final hasValue = _selectedCurrency.isNotEmpty;
    final isEditing = _fieldEditStates['currency'] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: isEditing ? _showCurrencyPicker : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isEditing ? kWhite : kGreyBg.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hasValue ? kPrimaryColor : kGrey200, width: hasValue ? 1.5 : 1)
          ),
          child: Row(
            children: [
              Icon(Icons.currency_exchange_rounded, color: isEditing ? kPrimaryColor : kGrey400, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Business Currency", style: TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w800)),
                    Text("${sel['symbol']} ${sel['code']} - ${sel['name']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87))
                  ]
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    String searchQuery = ''; // Declare outside to persist across rebuilds
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCurrencies = _currencies.where((currency) {
              if (searchQuery.isEmpty) return true;
              final query = searchQuery.toLowerCase();
              return currency['code']!.toLowerCase().contains(query) ||
                     currency['name']!.toLowerCase().contains(query) ||
                     currency['symbol']!.toLowerCase().contains(query);
            }).toList();

            return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text("Select Currency", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack87)),
                const SizedBox(height: 16),
                // Search Bar
                TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search currency code, name or symbol...',
                    hintStyle: const TextStyle(fontSize: 13, color: kGrey400),
                    prefixIcon: const Icon(Icons.search, color: kPrimaryColor, size: 20),
                    filled: true,
                    fillColor: kGreyBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setModalState(() {
                      searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Results count
                if (searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${filteredCurrencies.length} ${filteredCurrencies.length == 1 ? 'currency' : 'currencies'} found',
                        style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                // Currency List
                Expanded(
                  child: filteredCurrencies.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: kGrey400),
                              SizedBox(height: 12),
                              Text('No currencies found', style: TextStyle(color: kGrey400, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredCurrencies.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final currency = filteredCurrencies[i];
                            final isSelected = _selectedCurrency == currency['code'];
                            return ListTile(
                              onTap: () {
                                setState(() => _selectedCurrency = currency['code']!);
                                Navigator.pop(context);
                              },
                              leading: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? kPrimaryColor.withOpacity(0.1) : kGreyBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  currency['symbol']!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? kPrimaryColor : kBlack87,
                                  ),
                                ),
                              ),
                              title: Text(
                                currency['name']!,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? kPrimaryColor : kBlack87,
                                ),
                              ),
                              subtitle: Text(
                                currency['code']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? kPrimaryColor : kBlack54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: kPrimaryColor, size: 24)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
            );
          },
        );
      },
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
  List<BluetoothDevice> _bondedDevices = [];
  BluetoothDevice? _selectedDevice;
  String _printerWidth = '58mm';

  @override void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableAutoPrint = prefs.getBool('enable_auto_print') ?? true;
      _printerWidth = prefs.getString('printer_width') ?? '58mm';
    });
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

  Future<void> _setPrinterWidth(String width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_width', width);
    if (mounted) setState(() => _printerWidth = width);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text("Printer Setup", style: TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: kPrimaryColor, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_selectedDevice != null) Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGoogleGreen.withOpacity(0.3))), child: Row(children: [const Icon(Icons.print_rounded, color: kGoogleGreen, size: 28), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("ACTIVE PRINTER", style: TextStyle(fontSize: 9, color: kGoogleGreen, fontWeight: FontWeight.w900, letterSpacing: 0.5)), Text(_selectedDevice!.platformName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kBlack87))])), IconButton(onPressed: () => setState(() => _selectedDevice = null), icon: const Icon(Icons.delete_sweep_rounded, color: kErrorColor))])),

          // Printer Width Setting
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGrey200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("PAPER WIDTH", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _setPrinterWidth('58mm'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _printerWidth == '58mm' ? kPrimaryColor : kGreyBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _printerWidth == '58mm' ? kPrimaryColor : kGrey300),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_rounded, color: _printerWidth == '58mm' ? kWhite : kBlack54, size: 24),
                              const SizedBox(height: 6),
                              Text("58mm", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _printerWidth == '58mm' ? kWhite : kBlack87)),
                              Text("2 inch", style: TextStyle(fontSize: 10, color: _printerWidth == '58mm' ? kWhite.withOpacity(0.8) : kBlack54)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _setPrinterWidth('80mm'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _printerWidth == '80mm' ? kPrimaryColor : kGreyBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _printerWidth == '80mm' ? kPrimaryColor : kGrey300),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_rounded, color: _printerWidth == '80mm' ? kWhite : kBlack54, size: 24),
                              const SizedBox(height: 6),
                              Text("80mm", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _printerWidth == '80mm' ? kWhite : kBlack87)),
                              Text("3 inch", style: TextStyle(fontSize: 10, color: _printerWidth == '80mm' ? kWhite.withOpacity(0.8) : kBlack54)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Text("PAIRED DEVICES", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          _buildDeviceList(),
          const SizedBox(height: 24),
          _SettingsGroup(children: [_SwitchTile("Auto Print Receipt", _enableAutoPrint, (v) async { (await SharedPreferences.getInstance()).setBool('enable_auto_print', v); setState(() => _enableAutoPrint = v); }, showDivider: false)]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _isScanning ? null : _scanForDevices, backgroundColor: kPrimaryColor, icon: _isScanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Icon(Icons.bluetooth_searching_rounded,color: kWhite), label: Text(_isScanning ? "SCANNING..." : "SCAN FOR PRINTERS", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12,color: kWhite))),
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
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kGreyBg, appBar: AppBar(title: const Text("Features", style: TextStyle(color: kWhite,fontWeight: FontWeight.bold)), backgroundColor: kPrimaryColor, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack)), body: ListView(padding: const EdgeInsets.all(16), children: [_SettingsGroup(children: [_SwitchTile("Auto Print Receipt", _enableAutoPrint, (v) => setState(() => _enableAutoPrint = v)), _SwitchTile("Block Out-of-Stock Sales", _blockOutOfStock, (v) => setState(() => _blockOutOfStock = v)), Padding(padding: const EdgeInsets.all(16), child: Column(children: [Row(children: [const Text("Decimal Precision", style: TextStyle(fontWeight: FontWeight.w700)), const Spacer(), Text(_decimals.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor))]), Slider(value: _decimals, min: 0, max: 4, divisions: 4, activeColor: kPrimaryColor, onChanged: (v) => setState(() => _decimals = v))]))])]));
}

// ==========================================
// SHARED UI HELPERS (ENTERPRISE FLAT)
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
        backgroundColor: kGreyBg,
        appBar: AppBar(
          title: const Text("RECEIPT SETTINGS", style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
          backgroundColor: kPrimaryColor,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kWhite, size: 18),
              onPressed: onBack
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Accent
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                decoration: const BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Hub Configuration", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kWhite)),
                    const SizedBox(height: 8),
                    Text("Manage your thermal hardware and aesthetic presentation in one place.",
                        style: TextStyle(fontSize: 13, color: kWhite.withOpacity(0.8), height: 1.4, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActionTile(
                      title: "Design Engine",
                      description: "Customize templates, branding, and visibility.",
                      icon: Icons.auto_awesome_mosaic_rounded,
                      color: Colors.indigo,
                      onTap: () => onNavigate('ReceiptCustomization'),
                    ),
                    const SizedBox(height: 16),
                    _buildActionTile(
                      title: "Printer Link",
                      description: "Manage thermal hardware and Bluetooth link.",
                      icon: Icons.print_rounded,
                      color: Colors.blue,
                      onTap: () => onNavigate('PrinterSetup'),
                    ),

                    const SizedBox(height: 40),
                    _buildSectionHeader("OPERATIONAL STATUS"),
                    const SizedBox(height: 16),
                    _buildStatusItem("Thermal Engine", "Ready", true),
                    _buildStatusItem("Cloud Synchronization", "Active", true),
                  ],
                ),
              ),
            ],
          ),
        )
    );
  }

  Widget _buildActionTile({required String title, required String description, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kGrey200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kBlack87)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: kGrey400, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String status, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGrey200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kBlack87)),
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: isActive ? Colors.green : Colors.red, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 2.0));
  }
}

class ReceiptCustomizationPage extends StatefulWidget {
  final VoidCallback onBack;
  const ReceiptCustomizationPage({super.key, required this.onBack});
  @override State<ReceiptCustomizationPage> createState() => _ReceiptCustomizationPageState();
}

class _ReceiptCustomizationPageState extends State<ReceiptCustomizationPage> {
  bool _saving = false;
  int _selectedTemplateIndex = 0;

  final _docTitleCtrl = TextEditingController(text: 'INVOICE');
  bool _showLogo = true;
  bool _showLocation = true;
  bool _showEmail = true;
  bool _showPhone = true;
  bool _showTaxId = true;

  bool _showCustomer = true;
  bool _showUnits = true;
  bool _showMRP = false;
  bool _showPayMode = true;
  bool _showSavings = true;

  // Document number counters
  final _invoiceNumberCtrl = TextEditingController(text: '100001');
  final _quotationNumberCtrl = TextEditingController(text: '100001');
  final _purchaseNumberCtrl = TextEditingController(text: '100001');
  final _expenseNumberCtrl = TextEditingController(text: '100001');

  // Live current numbers (what will actually be used next)
  String _liveInvoiceNumber = '...';
  String _liveQuotationNumber = '...';
  String _livePurchaseNumber = '...';
  String _liveExpenseNumber = '...';
  bool _loadingLiveNumbers = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLiveNumbers();
  }

  /// Load the actual next numbers that will be used
  Future<void> _loadLiveNumbers() async {
    setState(() => _loadingLiveNumbers = true);
    try {
      final results = await Future.wait([
        NumberGeneratorService.generateInvoiceNumber(),
        NumberGeneratorService.generateQuotationNumber(),
        NumberGeneratorService.generateExpenseNumber(),
        NumberGeneratorService.generatePurchaseNumber(),
      ]);
      if (mounted) {
        setState(() {
          _liveInvoiceNumber = results[0];
          _liveQuotationNumber = results[1];
          _liveExpenseNumber = results[2];
          _livePurchaseNumber = results[3];
          _loadingLiveNumbers = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading live numbers: $e');
      if (mounted) setState(() => _loadingLiveNumbers = false);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTemplateIndex = prefs.getInt('invoice_template') ?? 0;
      _docTitleCtrl.text = prefs.getString('receipt_header') ?? 'INVOICE';
      _showLogo = prefs.getBool('receipt_show_logo') ?? true;
      _showLocation = prefs.getBool('receipt_show_location') ?? true;
      _showEmail = prefs.getBool('receipt_show_email') ?? true;
      _showPhone = prefs.getBool('receipt_show_phone') ?? true;
      _showTaxId = prefs.getBool('receipt_show_gst') ?? true;
      _showCustomer = prefs.getBool('receipt_show_customer_details') ?? true;
      _showUnits = prefs.getBool('receipt_show_measuring_unit') ?? true;
      _showMRP = prefs.getBool('receipt_show_mrp') ?? false;
      _showPayMode = prefs.getBool('receipt_show_payment_mode') ?? true;
      _showSavings = prefs.getBool('receipt_show_save_amount') ?? true;
    });

    // Load document number counters from Firestore
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _invoiceNumberCtrl.text = (data['nextInvoiceNumber'] ?? data['invoiceCounter'] ?? 100001).toString();
            _quotationNumberCtrl.text = (data['nextQuotationNumber'] ?? data['quotationCounter'] ?? 100001).toString();
            _purchaseNumberCtrl.text = (data['nextPurchaseNumber'] ?? data['purchaseCounter'] ?? 100001).toString();
            _expenseNumberCtrl.text = (data['nextExpenseNumber'] ?? data['expenseCounter'] ?? 100001).toString();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading document counters: $e');
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('invoice_template', _selectedTemplateIndex);
    await prefs.setString('receipt_header', _docTitleCtrl.text);
    await prefs.setBool('receipt_show_logo', _showLogo);
    await prefs.setBool('receipt_show_location', _showLocation);
    await prefs.setBool('receipt_show_email', _showEmail);
    await prefs.setBool('receipt_show_phone', _showPhone);
    await prefs.setBool('receipt_show_gst', _showTaxId);
    await prefs.setBool('receipt_show_customer_details', _showCustomer);
    await prefs.setBool('receipt_show_measuring_unit', _showUnits);
    await prefs.setBool('receipt_show_mrp', _showMRP);
    await prefs.setBool('receipt_show_payment_mode', _showPayMode);
    await prefs.setBool('receipt_show_save_amount', _showSavings);

    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId != null) {
      // Parse document numbers with validation (default to 100001)
      final invoiceNum = int.tryParse(_invoiceNumberCtrl.text) ?? 100001;
      final quotationNum = int.tryParse(_quotationNumberCtrl.text) ?? 100001;
      final purchaseNum = int.tryParse(_purchaseNumberCtrl.text) ?? 100001;
      final expenseNum = int.tryParse(_expenseNumberCtrl.text) ?? 100001;

      debugPrint('💾 Saving document numbers: Invoice=$invoiceNum, Quotation=$quotationNum, Purchase=$purchaseNum, Expense=$expenseNum');

      await FirebaseFirestore.instance.collection('store').doc(storeId).update({
        'invoiceSettings.template': _selectedTemplateIndex,
        'invoiceSettings.header': _docTitleCtrl.text,
        'invoiceSettings.showLogo': _showLogo,
        'invoiceSettings.showLocation': _showLocation,
        'invoiceSettings.showEmail': _showEmail,
        'invoiceSettings.showPhone': _showPhone,
        'invoiceSettings.showGST': _showTaxId,
        'invoiceSettings.showCustomerDetails': _showCustomer,
        'invoiceSettings.showMeasuringUnit': _showUnits,
        'invoiceSettings.showMRP': _showMRP,
        'invoiceSettings.showPaymentMode': _showPayMode,
        'invoiceSettings.showSaveAmount': _showSavings,
        // Document number counters
        'nextInvoiceNumber': invoiceNum,
        'nextQuotationNumber': quotationNum,
        'nextPurchaseNumber': purchaseNum,
        'nextExpenseNumber': expenseNum,
      });
    }

    // Refresh live numbers after saving
    await _loadLiveNumbers();

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: kGoogleGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanProvider>();

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: const Text("DESIGN ENGINE", style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2.0)),
        backgroundColor: kPrimaryColor,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: widget.onBack),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionHeader("AESTHETIC PRESET"),
                const SizedBox(height: 16),
                _buildTemplateGrid(),
                const SizedBox(height: 40),

                _buildSettingsSection("Identity & Branding", [
                  _buildInputField(_docTitleCtrl, "Header Label"),
                  _buildToggleItem("Include Business Logo", _showLogo, (v) {
                    if (!plan.canUseLogoOnBill()) {
                      PlanPermissionHelper.showUpgradeDialog(context, 'Logo');
                      return;
                    }
                    setState(() => _showLogo = v);
                  }),
                  _buildToggleItem("Show Business Address", _showLocation, (v) => setState(() => _showLocation = v)),
                  _buildToggleItem("Show Contact Email", _showEmail, (v) => setState(() => _showEmail = v)),
                  _buildToggleItem("Show Phone Number", _showPhone, (v) => setState(() => _showPhone = v)),
                  _buildToggleItem("Show Taxation (GST/VAT)", _showTaxId, (v) => setState(() => _showTaxId = v)),
                ]),

                const SizedBox(height: 32),

                _buildSettingsSection("Visibility Controls", [
                  _buildToggleItem("Customer Information", _showCustomer, (v) => setState(() => _showCustomer = v)),
                  _buildToggleItem("Measuring Units", _showUnits, (v) => setState(() => _showUnits = v)),
                  _buildToggleItem("Show MRP Column", _showMRP, (v) => setState(() => _showMRP = v)),
                  _buildToggleItem("Show Payment Mode", _showPayMode, (v) => setState(() => _showPayMode = v)),
                  _buildToggleItem("Display Savings Alert", _showSavings, (v) => setState(() => _showSavings = v)),
                ]),

                const SizedBox(height: 32),

                // Current Document Numbers with Edit Option
                _buildSettingsSection("Current Document Numbers", [
                  _buildEditableNumberField(_invoiceNumberCtrl, "Next Invoice Number", Icons.receipt_long_rounded, kPrimaryColor, _liveInvoiceNumber),
                  _buildEditableNumberField(_quotationNumberCtrl, "Next Quotation Number", Icons.request_quote_rounded, Colors.orange, _liveQuotationNumber),
                  _buildEditableNumberField(_purchaseNumberCtrl, "Next Purchase Number", Icons.shopping_cart_rounded, Colors.green, _livePurchaseNumber),
                  _buildEditableNumberField(_expenseNumberCtrl, "Next Expense Number", Icons.account_balance_wallet_rounded, Colors.purple, _liveExpenseNumber),
                ]),
                const SizedBox(height: 40),
              ],
            ),
          ),
          _buildActionFooter(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 2.0));
  }

  Widget _buildTemplateGrid() {
    final items = [
      {'t': 'Professional', 'c': Colors.black87},
      {'t': 'Modern Blue', 'c': kPrimaryColor},
      {'t': 'Minimalist', 'c': Colors.blueGrey},
      {'t': 'Vibrant', 'c': Colors.indigo},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(items.length, (i) {
        bool sel = _selectedTemplateIndex == i;
        Color col = items[i]['c'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _selectedTemplateIndex = i),
          child: Container(
            width: (MediaQuery.of(context).size.width - 60) / 2,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: sel ? col : kWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sel ? col : kGrey200, width: 1.5),
              boxShadow: sel ? [BoxShadow(color: col.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
            ),
            child: Column(
              children: [
                Icon(Icons.description_outlined, color: sel ? kWhite : kGrey400, size: 28),
                const SizedBox(height: 8),
                Text(items[i]['t'] as String,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: sel ? kWhite : kBlack87)),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kBlack87)),
        ),
        Container(
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kGrey200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggleItem(String label, bool val, Function(bool) fn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGrey100))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBlack87)),
          CupertinoSwitch(value: val, onChanged: fn, activeColor: kPrimaryColor),
        ],
      ),
    );
  }

  Widget _buildEditableNumberField(TextEditingController ctrl, String label, IconData icon, Color color, String liveValue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGrey100))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack54)),
                const SizedBox(height: 4),
                _loadingLiveNumbers
                    ? const SizedBox(width: 80, height: 24, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
                    : Text(liveValue, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
          // Edit button
          GestureDetector(
            onTap: () => _showEditNumberDialog(ctrl, label, icon, color, liveValue),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.edit_rounded, size: 14, color: kPrimaryColor),
                  SizedBox(width: 4),
                  Text("Edit", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kPrimaryColor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNumberDialog(TextEditingController ctrl, String label, IconData icon, Color color, String currentValue) {
    final editCtrl = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter the next number to use:", style: TextStyle(fontSize: 12, color: kBlack54)),
            const SizedBox(height: 12),
            TextField(
              controller: editCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
              decoration: InputDecoration(
                filled: true,
                fillColor: color.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "💡 This will be the next number used for new documents.",
              style: TextStyle(fontSize: 10, color: kBlack54, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: kBlack54, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newValue = int.tryParse(editCtrl.text);
              if (newValue != null && newValue > 0) {
                ctrl.text = editCtrl.text;
                Navigator.pop(context);
                // Save settings and refresh live numbers
                await _saveSettings();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid number"), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Save", style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGrey100))),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kBlack87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600),
          border: InputBorder.none,
        ),
      ),
    );
  }


  Widget _buildActionFooter() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        decoration: BoxDecoration(
          color: kWhite,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              _saving ? "Syncing..." : "Save configuration",
              style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13),
            ),
          ),
        ),
      ),
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
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text("Select Language", style: TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 16)), centerTitle: true, backgroundColor: kPrimaryColor, leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: onBack)),
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


class ThemePage extends StatelessWidget { final VoidCallback onBack; const ThemePage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("Theme", onBack); }
class HelpPage extends StatelessWidget { final VoidCallback onBack; final Function(String) onNavigate; const HelpPage({super.key, required this.onBack, required this.onNavigate}); @override Widget build(BuildContext context) => _SimplePage("Help & Support", onBack); }
class FAQsPage extends StatelessWidget { final VoidCallback onBack; const FAQsPage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("Frequently Asked Questions", onBack); }
class UpcomingFeaturesPage extends StatelessWidget { final VoidCallback onBack; const UpcomingFeaturesPage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("New Features", onBack); }
class VideoTutorialsPage extends StatelessWidget { final VoidCallback onBack; const VideoTutorialsPage({super.key, required this.onBack}); @override Widget build(BuildContext context) => _SimplePage("Tutorial Videos", onBack); }
class _SimplePage extends StatelessWidget {
  final String title; final VoidCallback onBack; const _SimplePage(this.title, this.onBack);
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: kGreyBg, appBar: AppBar(title: Text(title, style: const TextStyle(color: kWhite,fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: kPrimaryColor, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: kWhite, size: 18), onPressed: onBack)), body: Center(child: Text("$title Content Loading...", style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w600))));
}