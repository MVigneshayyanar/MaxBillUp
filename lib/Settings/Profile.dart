import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/Auth/LoginPage.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/printer_service.dart';
import 'package:printing/printing.dart';

// ==========================================
// CONSTANTS & STYLES
// ==========================================
const Color kPrimaryColor = Color(0xFF007AFF); // iOS Blue
const Color kBgColor = Color(0xFFF2F2F7); // iOS Light Gray
const Color kDangerColor = Color(0xFFFF3B30);

// ==========================================
// 1. MAIN SETTINGS PAGE (ROUTER)
// ==========================================

class SettingsPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const SettingsPage({super.key, required this.uid, this.userEmail});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Navigation State
  String? _currentView;
  final List<String> _viewHistory = []; // To handle nested "Back" navigation

  // User Data
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (mounted) {
        setState(() {
          _userData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Navigation Helpers
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

    // ------------------------------------------
    // CONDITIONAL RENDERING SWITCH
    // ------------------------------------------
    switch (_currentView) {
      case 'BusinessDetails':
        return BusinessDetailsPage(uid: widget.uid, onBack: _goBack);

      case 'ReceiptSettings':
        return ReceiptSettingsPage(
          onBack: _goBack,
          onNavigate: _navigateTo, // Pass navigator to allow nesting
        );

      case 'ReceiptCustomization':
        return ReceiptCustomizationPage(onBack: _goBack);

      case 'TaxSettings':
        return TaxSettingsPage(onBack: _goBack);

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

    // ------------------------------------------
    // DEFAULT VIEW (MAIN SETTINGS LIST)
    // ------------------------------------------
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: kBgColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Hide back button on root
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 24),

          _buildSectionTitle("App Settings"),
          _SettingsGroup(children: [
            _SettingsTile(
              icon: Icons.store_mall_directory_outlined,
              title: "Business Details",
              onTap: () => _navigateTo('BusinessDetails'),
            ),
            _SettingsTile(
              icon: Icons.receipt_long_outlined,
              title: "Receipt",
              onTap: () => _navigateTo('ReceiptSettings'),
            ),
            _SettingsTile(
              icon: Icons.percent_outlined,
              title: "TAX / WAT",
              onTap: () => _navigateTo('TaxSettings'),
            ),
            _SettingsTile(
              icon: Icons.print_outlined,
              title: "Printer Setup",
              onTap: () => _navigateTo('PrinterSetup'),
            ),
            _SettingsTile(
              icon: Icons.tune_outlined,
              title: "Feature Settings",
              onTap: () => _navigateTo('FeatureSettings'),
            ),
            _SettingsTile(
              icon: Icons.language_outlined,
              title: "Languages",
              onTap: () => _navigateTo('Language'),
            ),
            _SettingsTile(
              icon: Icons.dark_mode_outlined,
              title: "Theme",
              showDivider: false,
              onTap: () => _navigateTo('Theme'),
            ),
          ]),

          const SizedBox(height: 24),
          _buildSectionTitle("Support & Service"),
          _SettingsGroup(children: [
            _SettingsTile(
              icon: Icons.help_outline,
              title: "Help",
              onTap: () => _navigateTo('Help'),
            ),
            _SettingsTile(icon: Icons.storefront_outlined, title: "Market Place", onTap: () {}),
            _SettingsTile(icon: Icons.share_outlined, title: "Refer A Friend", showDivider: false, onTap: () {}),
          ]),

          const SizedBox(height: 24),
          const Center(child: Text('v .5167', style: TextStyle(color: Colors.grey, fontSize: 13))),
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
    final name = _userData?['businessName'] ?? _userData?['name'] ?? 'User';
    final email = _userData?['email'] ?? widget.userEmail ?? '';
    final role = _userData?['role'] ?? 'Administrator';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey[200],
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : "U", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(role, style: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          // Logout essentially leaves this entire screen structure, so Navigator is correct here
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kDangerColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: Colors.white,
        ),
        child: const Text("logout", style: TextStyle(color: kDangerColor, fontSize: 16)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
  );
}

// ==========================================
// 2. RECEIPT SETTINGS PAGES
// ==========================================

class ReceiptSettingsPage extends StatelessWidget {
  final VoidCallback onBack;
  final Function(String) onNavigate; // To navigate deeper

  const ReceiptSettingsPage({super.key, required this.onBack, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Receipt Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsGroup(children: [
            _SettingsTile(
              title: "Thermal Printer",
              subtitle: "Customize the 58mm and 80mm receipt",
              icon: Icons.print,
              showDivider: true,
              onTap: () => onNavigate('PrinterSetup'), // Navigate Deeper
            ),
            _SettingsTile(
              title: "A4 Size / PDF",
              subtitle: "Customize the A4 Size",
              icon: Icons.picture_as_pdf,
              showDivider: false,
              onTap: () => onNavigate('ReceiptCustomization'), // Navigate Deeper
            ),
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
  bool _showPhone = false;
  bool _showGST = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Receipt Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildExpansionSection("Company Info", [
            _SwitchTile("Company Logo", _showLogo, (v) => setState(() => _showLogo = v)),
            _SwitchTile("Email", _showEmail, (v) => setState(() => _showEmail = v)),
            _SwitchTile("Phone Number", _showPhone, (v) => setState(() => _showPhone = v)),
            _SwitchTile("GST Number", _showGST, (v) => setState(() => _showGST = v), showDivider: false),
          ]),
          const SizedBox(height: 16),
          _buildExpansionSection("Item Table", [
            const Padding(padding: EdgeInsets.all(16), child: Text("Item table configuration here...")),
          ], isExpanded: false),
          const SizedBox(height: 16),
          _buildExpansionSection("Invoice Footer", [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Footer Description:", style: TextStyle(fontSize: 13, color: Colors.black54)),
                  SizedBox(height: 8),
                  _SimpleTextField(hint: "Bill Description"),
                  SizedBox(height: 16),
                  Text("Footer Image:", style: TextStyle(fontSize: 13, color: Colors.black54)),
                  SizedBox(height: 8),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _buildExpansionSection("Quotation footer setup", [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Quotation Description", style: TextStyle(fontSize: 13, color: Colors.black54)),
                  SizedBox(height: 8),
                  _SimpleTextField(hint: "", maxLines: 3),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 30),
          _PrimaryButton(text: "Update", onTap: widget.onBack),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildExpansionSection(String title, List<Widget> children, {bool isExpanded = true}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black)),
          initiallyExpanded: isExpanded,
          children: children,
        ),
      ),
    );
  }
}

// ==========================================
// 3. TAX / WAT SETTINGS PAGE
// ==========================================

class TaxSettingsPage extends StatefulWidget {
  final VoidCallback onBack;
  const TaxSettingsPage({super.key, required this.onBack});

  @override
  State<TaxSettingsPage> createState() => _TaxSettingsPageState();
}

class _TaxSettingsPageState extends State<TaxSettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _taxes = [
    {'val': 5.0, 'name': 'GST', 'active': true, 'count': 0},
    {'val': 12.0, 'name': 'GST', 'active': false, 'count': 0},
    {'val': 18.0, 'name': 'GST', 'active': false, 'count': 0},
    {'val': 66.0, 'name': 'GST', 'active': false, 'count': 0},
  ];

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Tax Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: kBgColor, borderRadius: BorderRadius.circular(8)),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(8)),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black54,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: "Taxes"), Tab(text: "Tax for Quick Sale")],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text("Add New Tax", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _SimpleDropdown(value: "Tax", items: const ["Tax", "VAT"])),
                        const SizedBox(width: 12),
                        const Expanded(child: _SimpleTextField(hint: "Tax %")),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            minimumSize: const Size(80, 48),
                          ),
                          child: const Text("Add", style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsGroup(children: _taxes.map((t) => _TaxListTile(t)).toList()),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text("Default Tax for QuickSale", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: "Price is without Tax",
                          isExpanded: true,
                          items: const [DropdownMenuItem(value: "Price is without Tax", child: Text("Price is without Tax", style: TextStyle(color: Colors.grey)))],
                          onChanged: (v) {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SettingsGroup(children: _taxes.map((t) => _TaxSwitchTile(t, (v) {
                      setState(() { t['active'] = v; });
                    })).toList()),
                    const SizedBox(height: 30),
                    _PrimaryButton(text: "Update", onTap: widget.onBack),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _TaxListTile(Map<String, dynamic> tax) {
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: kPrimaryColor.withOpacity(0.1),
            child: Text("${tax['val']}%", style: const TextStyle(fontSize: 11, color: kPrimaryColor, fontWeight: FontWeight.bold)),
          ),
          title: Text(tax['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${tax['count']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text("Products", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
        if (tax != _taxes.last) const Divider(height: 1, indent: 70),
      ],
    );
  }

  Widget _TaxSwitchTile(Map<String, dynamic> tax, Function(bool) onChanged) {
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: kPrimaryColor.withOpacity(0.1),
            child: Text("${tax['val']}%", style: const TextStyle(fontSize: 11, color: kPrimaryColor, fontWeight: FontWeight.bold)),
          ),
          title: Text(tax['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: Switch(
            value: tax['active'],
            onChanged: onChanged,
            activeColor: kPrimaryColor,
          ),
        ),
        if (tax != _taxes.last) const Divider(height: 1, indent: 70),
      ],
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
  bool _isScanning = false;
  List<Printer> _availablePrinters = [];
  String? _selectedPrinter;
  bool _enableAutoPrint = true;
  String _printerSize = '80MM (3 inch)';
  String _fontSize = 'Medium';

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
  }

  Future<void> _loadSavedPrinter() async {
    final savedPrinter = await PrinterService.getSavedPrinter();
    if (mounted) {
      setState(() {
        _selectedPrinter = savedPrinter;
      });
    }
  }

  Future<void> _scanForPrinters() async {
    setState(() {
      _isScanning = true;
      _availablePrinters = [];
    });

    try {
      final printers = await PrinterService.discoverPrinters();
      if (mounted) {
        setState(() {
          _availablePrinters = printers;
          _isScanning = false;
        });

        if (printers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No printers found. Make sure your printer is connected and turned on.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning for printers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectPrinter(String printerName) async {
    await PrinterService.saveSelectedPrinter(printerName);
    setState(() {
      _selectedPrinter = printerName;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Printer "$printerName" selected successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _disconnectPrinter() async {
    await PrinterService.clearSavedPrinter();
    setState(() {
      _selectedPrinter = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer disconnected'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Printer Setup", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current Printer Status
          if (_selectedPrinter != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connected Printer',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedPrinter!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _disconnectPrinter,
                    tooltip: 'Disconnect',
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No printer connected. Scan for nearby printers to connect.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Scan for Printers Button
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _scanForPrinters,
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.search, color: Colors.white),
            label: Text(
              _isScanning ? 'Scanning...' : 'Scan for Printers',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 24),

          // Available Printers List
          if (_availablePrinters.isNotEmpty) ...[
            const Text(
              'Available Printers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _SettingsGroup(
              children: _availablePrinters.map((printer) {
                final isSelected = _selectedPrinter == printer.name;
                return ListTile(
                  leading: Icon(
                    Icons.print,
                    color: isSelected ? kPrimaryColor : Colors.grey,
                  ),
                  title: Text(
                    printer.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? kPrimaryColor : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    printer.isAvailable ? 'Available' : 'Unavailable',
                    style: TextStyle(
                      color: printer.isAvailable ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: kPrimaryColor)
                      : null,
                  onTap: printer.isAvailable
                      ? () => _selectPrinter(printer.name)
                      : null,
                  enabled: printer.isAvailable,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Printer Settings
          const Text(
            'Printer Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsGroup(
            children: [
              _DropdownTile(
                'Printer Size',
                _printerSize,
                ['58MM (2 inch)', '80MM (3 inch)'],
                (value) => setState(() => _printerSize = value!),
              ),
              _DropdownTile(
                'Font Size',
                _fontSize,
                ['Small', 'Medium', 'Large'],
                (value) => setState(() => _fontSize = value!),
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Auto Print Toggle
          _SettingsGroup(
            children: [
              _SwitchTile(
                'Enable Auto Print',
                _enableAutoPrint,
                (v) => setState(() => _enableAutoPrint = v),
                showDivider: false,
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Save Button
          _PrimaryButton(
            text: 'Save Settings',
            onTap: widget.onBack,
          ),
        ],
      ),
    );
  }

  Widget _DropdownTile(
    String label,
    String value,
    List<String> options,
    void Function(String?) onChanged, {
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: kBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    items: options
                        .map((opt) => DropdownMenuItem(
                              value: opt,
                              child: Text(
                                opt,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ))
                        .toList(),
                    onChanged: onChanged,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 16),
      ],
    );
  }
}

// ==========================================
// 5. FEATURE SETTINGS PAGE
// ==========================================

class FeatureSettingsPage extends StatefulWidget {
  final VoidCallback onBack;
  const FeatureSettingsPage({super.key, required this.onBack});

  @override
  State<FeatureSettingsPage> createState() => _FeatureSettingsPageState();
}

class _FeatureSettingsPageState extends State<FeatureSettingsPage> {
  bool _enableAutoPrint = true;
  bool _blockOutOfStock = true;
  double _decimalPoints = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Feature Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsGroup(children: [
            _SwitchTile("Enable Auto Print", _enableAutoPrint, (v) => setState(() => _enableAutoPrint = v), hasInfo: true),
            _SwitchTile("Block out of Stock Sale", _blockOutOfStock, (v) => setState(() => _blockOutOfStock = v), hasInfo: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text("Decimal Points", style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 6),
                      Icon(Icons.info, size: 16, color: kPrimaryColor),
                      const Spacer(),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _decimalPoints,
                          min: 0,
                          max: 4,
                          divisions: 4,
                          label: _decimalPoints.round().toString(),
                          activeColor: kPrimaryColor,
                          onChanged: (v) => setState(() => _decimalPoints = v),
                        ),
                      ),
                      Text(_decimalPoints.round().toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  )
                ],
              ),
            )
          ]),
        ],
      ),
    );
  }
}

// ==========================================
// 6. LANGUAGE PAGE
// ==========================================

class LanguagePage extends StatefulWidget {
  final VoidCallback onBack;
  const LanguagePage({super.key, required this.onBack});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  String _selectedLang = 'English';

  final List<Map<String, String>> _langs = [
    {'name': 'English', 'native': '', 'tag': ''},
    {'name': 'Français', 'native': 'French', 'tag': ''},
    {'name': 'हिंदी', 'native': 'Hindi', 'tag': 'Beta'},
    {'name': 'Español', 'native': 'Spanish', 'tag': 'Beta'},
    {'name': 'தமிழ்', 'native': 'Tamil', 'tag': 'Beta'},
    {'name': 'Bahasa Melayu', 'native': 'Malay', 'tag': 'Beta'},
    {'name': 'বাংলা', 'native': 'Bangla', 'tag': 'Beta'},
    {'name': 'O\'zbek', 'native': 'Uzbek', 'tag': 'Beta'},
    {'name': 'Русский', 'native': 'Russian', 'tag': 'Beta'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Choose Language", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _langs.length,
          itemBuilder: (context, index) {
            final lang = _langs[index];
            final isSelected = _selectedLang == lang['name'];
            return GestureDetector(
              onTap: () => setState(() => _selectedLang = lang['name']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? kPrimaryColor : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(lang['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (lang['native']!.isNotEmpty)
                          Text(lang['native']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    if (isSelected)
                      const Positioned(right: 0, top: 0, child: Icon(Icons.radio_button_checked, color: kPrimaryColor, size: 20))
                    else
                      Positioned(right: 0, top: 0, child: Icon(Icons.radio_button_off, color: Colors.grey.shade300, size: 20)),

                    if (lang['tag'] == 'Beta')
                      Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                            child: const Text("Beta", style: TextStyle(color: Colors.white, fontSize: 10)),
                          ))
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==========================================
// 7. BUSINESS DETAILS PAGE
// ==========================================
class BusinessDetailsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;
  const BusinessDetailsPage({super.key, required this.uid, required this.onBack});

  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  Map<String, dynamic> _permissions = {};
  String _role = 'staff';
  bool _isLoading = true;
  String? _storeId;

  // Text controllers for business details
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();

  // Additional fields from Firebase
  String? _ownerUid;
  String? _createdAt;
  String? _updatedAt;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load permissions
      final userData = await PermissionHelper.getUserPermissions(widget.uid);

      // Load store data
      final storeId = await FirestoreService().getCurrentStoreId();
      debugPrint('Loading business details for storeId: $storeId');

      if (storeId != null) {
        final storeDoc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(storeId)
            .get();

        if (storeDoc.exists) {
          final storeData = storeDoc.data() as Map<String, dynamic>;
          debugPrint('Store data loaded: $storeData');

          _businessNameController.text = storeData['businessName'] ?? '';
          _ownerNameController.text = storeData['ownerName'] ?? '';
          _phoneController.text = storeData['businessPhone'] ?? storeData['ownerPhone'] ?? '';
          _emailController.text = storeData['ownerEmail'] ?? '';
          _addressController.text = storeData['address'] ?? '';
          _gstinController.text = storeData['gstin'] ?? '';

          // Additional fields
          _ownerUid = storeData['ownerUid'];

          // Format timestamps
          if (storeData['createdAt'] != null) {
            final createdTimestamp = storeData['createdAt'] as Timestamp;
            _createdAt = DateFormat('dd MMM yyyy, hh:mm a').format(createdTimestamp.toDate());
          }

          if (storeData['updatedAt'] != null) {
            final updatedTimestamp = storeData['updatedAt'] as Timestamp;
            _updatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(updatedTimestamp.toDate());
          }

          debugPrint('Business Name: ${_businessNameController.text}');
          debugPrint('Owner Name: ${_ownerNameController.text}');
          debugPrint('Phone: ${_phoneController.text}');
          debugPrint('Email: ${_emailController.text}');
          debugPrint('Created At: $_createdAt');
          debugPrint('Updated At: $_updatedAt');
        } else {
          debugPrint('Store document does not exist for storeId: $storeId');
        }
      } else {
        debugPrint('StoreId is null');
      }

      if (mounted) {
        setState(() {
          _permissions = userData['permissions'] as Map<String, dynamic>;
          _role = userData['role'] as String;
          _storeId = storeId;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading business details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  bool get isAdmin => _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Business Details", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !isAdmin
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Admin Access Only',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Only administrators can edit business details. Contact your admin for changes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kPrimaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: kPrimaryColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Business details are synced from your account',
                                style: TextStyle(
                                  color: kPrimaryColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Business Information Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.business, color: kPrimaryColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Business Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildReadOnlyField('Business Name', Icons.store_mall_directory, _businessNameController.text),
                            const Divider(height: 32),
                            _buildReadOnlyField('Business Phone', Icons.phone_android, _phoneController.text),
                            const Divider(height: 32),
                            _buildReadOnlyField('Store ID', Icons.qr_code, _storeId ?? 'N/A'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Owner Information Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.person, color: kPrimaryColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Owner Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildReadOnlyField('Owner Name', Icons.badge, _ownerNameController.text),
                            const Divider(height: 32),
                            _buildReadOnlyField('Email Address', Icons.email, _emailController.text),
                            const Divider(height: 32),
                            _buildReadOnlyField('Phone Number', Icons.phone, _phoneController.text),
                            if (_ownerUid != null && _ownerUid!.isNotEmpty) ...[
                              const Divider(height: 32),
                              _buildReadOnlyField('Owner UID', Icons.fingerprint, _ownerUid!),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Additional Details Card
                      if (_addressController.text.isNotEmpty || _gstinController.text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: kPrimaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.info_outline, color: kPrimaryColor, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Additional Details',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (_addressController.text.isNotEmpty)
                                _buildReadOnlyField('Business Address', Icons.location_on, _addressController.text),
                              if (_addressController.text.isNotEmpty && _gstinController.text.isNotEmpty)
                                const Divider(height: 32),
                              if (_gstinController.text.isNotEmpty)
                                _buildReadOnlyField('GST Number', Icons.receipt_long, _gstinController.text),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // System Information Card
                      if (_createdAt != null || _updatedAt != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.access_time, color: Colors.grey, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'System Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (_createdAt != null)
                                _buildReadOnlyField('Account Created', Icons.calendar_today, _createdAt!),
                              if (_createdAt != null && _updatedAt != null)
                                const Divider(height: 32),
                              if (_updatedAt != null)
                                _buildReadOnlyField('Last Updated', Icons.update, _updatedAt!),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildReadOnlyField(String label, IconData icon, String value) {
    final isEmpty = value.isEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isEmpty ? Colors.grey.shade100 : kPrimaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isEmpty ? Colors.grey.shade400 : kPrimaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isEmpty ? 'Not provided' : value,
                style: TextStyle(
                  fontSize: 15,
                  color: isEmpty ? Colors.grey[400] : Colors.black87,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// THEME PAGE
// ==========================================
class ThemePage extends StatefulWidget {
  final VoidCallback onBack;
  const ThemePage({super.key, required this.onBack});

  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  String _selectedTheme = 'Light Mode'; // Default selection

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Theme", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pick the look that feels best for your eyes.',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 24),

            // Light Mode Option
            _buildThemeOption(
              'Light Mode',
              'Bright and clear for daytime use',
              _selectedTheme == 'Light Mode',
              () {
                setState(() {
                  _selectedTheme = 'Light Mode';
                });
              },
            ),
            const SizedBox(height: 16),

            // Dark Mode Option
            _buildThemeOption(
              'Dark Mode',
              'Easy on the eyes in low light',
              _selectedTheme == 'Dark Mode',
              () {
                setState(() {
                  _selectedTheme = 'Dark Mode';
                });
              },
            ),

            const Spacer(),

            // Update Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Save theme preference
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Theme updated to $_selectedTheme'),
                      backgroundColor: kPrimaryColor,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Update',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kPrimaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? kPrimaryColor : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? kPrimaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HELP PAGE
// ==========================================
class HelpPage extends StatelessWidget {
  final VoidCallback onBack;
  final Function(String) onNavigate;

  const HelpPage({super.key, required this.onBack, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Help", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHelpTile(
            'FAQs',
            Icons.question_answer_outlined,
            () => onNavigate('FAQs'),
          ),
          const SizedBox(height: 12),
          _buildHelpTile(
            'Upcoming Features',
            Icons.update_outlined,
            () => onNavigate('UpcomingFeatures'),
          ),
          const SizedBox(height: 12),
          _buildHelpTile(
            'Video Tutorials',
            Icons.play_circle_outline,
            () => onNavigate('VideoTutorials'),
          ),
          const SizedBox(height: 12),
          _buildHelpTile(
            'Chat Support',
            Icons.chat_outlined,
            () {
              // TODO: Implement WhatsApp chat support
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening chat support...')),
              );
            },
            showWhatsAppIcon: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpTile(String title, IconData icon, VoidCallback onTap, {bool showWhatsAppIcon = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black87, size: 24),
        title: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            if (showWhatsAppIcon) ...[
              const SizedBox(width: 8),
              const Icon(Icons.whatshot, color: Color(0xFF25D366), size: 20),
            ],
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

// ==========================================
// FAQs PAGE
// ==========================================
class FAQsPage extends StatelessWidget {
  final VoidCallback onBack;

  const FAQsPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("FAQs", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFAQCategory(
            context,
            'How to Connect Thermal Printer',
            'Printer Setup',
          ),
          const SizedBox(height: 12),
          _buildFAQCategory(
            context,
            'Sale / Billing',
            'Billing Tutorial',
          ),
          const SizedBox(height: 12),
          _buildFAQCategory(
            context,
            'Inventory / Stock',
            'Stock Management',
          ),
        ],
      ),
    );
  }

  Widget _buildFAQCategory(BuildContext context, String title, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: () {
          // Navigate to detailed FAQ page
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening $title')),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ==========================================
// UPCOMING FEATURES PAGE
// ==========================================
class UpcomingFeaturesPage extends StatelessWidget {
  final VoidCallback onBack;

  const UpcomingFeaturesPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Upcoming Features", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFeatureCard(
            'Multi-Store Management',
            'Manage multiple store locations from one dashboard',
            Icons.store,
            'Coming Q1 2026',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            'Advanced Analytics',
            'Detailed insights and predictive analytics',
            Icons.analytics,
            'Coming Q2 2026',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            'Barcode Scanner',
            'Fast product scanning for quick checkouts',
            Icons.qr_code_scanner,
            'Coming Q1 2026',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, String description, IconData icon, String timeline) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: kPrimaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeline,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// VIDEO TUTORIALS PAGE
// ==========================================
class VideoTutorialsPage extends StatelessWidget {
  final VoidCallback onBack;

  const VideoTutorialsPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Video Tutorials", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildVideoTile(
            context,
            'How to Create a Bill',
            'Learn how to create and manage bills efficiently',
            Icons.receipt_long,
          ),
          const SizedBox(height: 12),
          _buildVideoTile(
            context,
            'How to Add Products',
            'Step-by-step guide to adding products to inventory',
            Icons.add_shopping_cart,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTile(BuildContext context, String title, String description, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.play_circle_filled, color: Colors.red, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          description,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: () {
          // TODO: Open video player or YouTube link
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening video: $title')),
          );
        },
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}

// ==========================================
// HELPER WIDGETS (UI COMPONENTS)
// ==========================================

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
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
          leading: icon != null ? Icon(icon, color: Colors.black87, size: 22) : null,
          title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
          trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          onTap: onTap,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        if (showDivider) const Divider(height: 1, thickness: 0.5, indent: 56, endIndent: 0, color: Color(0xFFE5E5EA)),
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

  const _SwitchTile(this.title, this.value, this.onChanged, {this.showDivider = true, this.hasInfo = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
              if (hasInfo) ...[const SizedBox(width: 6), const Icon(Icons.info, size: 16, color: kPrimaryColor)],
              const Spacer(),
              Switch(value: value, onChanged: onChanged, activeColor: kPrimaryColor),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 16),
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
      decoration: BoxDecoration(color: kBgColor, borderRadius: BorderRadius.circular(6)),
      child: TextField(
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.all(12), isDense: true),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}