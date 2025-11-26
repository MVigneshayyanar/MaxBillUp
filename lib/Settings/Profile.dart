import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/Auth/LoginPage.dart';

// ==========================================
// CONSTANTS & STYLES
// ==========================================
const Color kPrimaryColor = Color(0xFF007AFF); // iOS Blue
const Color kBgColor = Color(0xFFF2F2F7); // iOS Light Gray
const Color kDangerColor = Color(0xFFFF3B30);

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: kBgColor,
        elevation: 0,
        centerTitle: true,
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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => BusinessDetailsPage(uid: widget.uid))).then((_) => _fetchUserData()),
            ),
            _SettingsTile(
              icon: Icons.receipt_long_outlined,
              title: "Receipt",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ReceiptSettingsPage())),
            ),
            _SettingsTile(
              icon: Icons.percent_outlined,
              title: "TAX / WAT",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TaxSettingsPage())),
            ),
            _SettingsTile(
              icon: Icons.print_outlined,
              title: "Printer Setup",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PrinterSetupPage())),
            ),
            _SettingsTile(
              icon: Icons.tune_outlined,
              title: "Feature Settings",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FeatureSettingsPage())),
            ),
            _SettingsTile(
              icon: Icons.language_outlined,
              title: "Languages",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LanguagePage())),
            ),
            _SettingsTile(
              icon: Icons.dark_mode_outlined,
              title: "Theme",
              showDivider: false,
              onTap: () {}, // Simple toggle can be added here
            ),
          ]),

          const SizedBox(height: 24),
          _buildSectionTitle("Support & Service"),
          _SettingsGroup(children: [
            _SettingsTile(icon: Icons.help_outline, title: "Help", onTap: () {}),
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
  const ReceiptSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Receipt Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsGroup(children: [
            _SettingsTile(
              title: "Thermal Printer",
              subtitle: "Customize the 58mm and 80mm receipt",
              icon: Icons.print, // Placeholder icon
              showDivider: true,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PrinterSetupPage())),
            ),
            _SettingsTile(
              title: "A4 Size / PDF",
              subtitle: "Customize the A4 Size",
              icon: Icons.picture_as_pdf, // Placeholder icon
              showDivider: false,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ReceiptCustomizationPage())),
            ),
          ]),
        ],
      ),
    );
  }
}

class ReceiptCustomizationPage extends StatefulWidget {
  const ReceiptCustomizationPage({super.key});

  @override
  State<ReceiptCustomizationPage> createState() => _ReceiptCustomizationPageState();
}

class _ReceiptCustomizationPageState extends State<ReceiptCustomizationPage> {
  // State variables for toggles
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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Company Info Section (Expansion Tile style)
          _buildExpansionSection("Company Info", [
            _SwitchTile("Company Logo", _showLogo, (v) => setState(() => _showLogo = v)),
            _SwitchTile("Email", _showEmail, (v) => setState(() => _showEmail = v)),
            _SwitchTile("Phone Number", _showPhone, (v) => setState(() => _showPhone = v)),
            _SwitchTile("GST Number", _showGST, (v) => setState(() => _showGST = v), showDivider: false),
          ]),
          const SizedBox(height: 16),

          // Item Table
          _buildExpansionSection("Item Table", [
            const Padding(padding: EdgeInsets.all(16), child: Text("Item table configuration here...")),
          ], isExpanded: false),
          const SizedBox(height: 16),

          // Invoice Footer
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

          // Quotation Footer
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
          _PrimaryButton(text: "Update", onTap: () => Navigator.pop(context)),
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
  const TaxSettingsPage({super.key});

  @override
  State<TaxSettingsPage> createState() => _TaxSettingsPageState();
}

class _TaxSettingsPageState extends State<TaxSettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Dummy data
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
                // Tab 1: Taxes (Add/List)
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
                // Tab 2: Tax for Quick Sale
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
                    _PrimaryButton(text: "Update", onTap: () => Navigator.pop(context)),
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
  const PrinterSetupPage({super.key});

  @override
  State<PrinterSetupPage> createState() => _PrinterSetupPageState();
}

class _PrinterSetupPageState extends State<PrinterSetupPage> {
  bool _enableAutoPrint = true;
  bool _openCashDrawer = false;
  bool _disconnect = false;
  bool _autoCut = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Thermal Printer Setup", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsGroup(children: [
            _DropdownTile("Printer Size :", "58MM (2 inch)"),
            _DropdownTile("Printer Mode :", "CONFIG - 1"),
            _DropdownTile("Font Size :", "Medium", showDivider: false),
          ]),
          const SizedBox(height: 24),
          _SettingsGroup(children: [
            _SwitchTile("Enable Auto Print :", _enableAutoPrint, (v) => setState(() => _enableAutoPrint = v)),
            _SwitchTile("Open Cash Drawer :", _openCashDrawer, (v) => setState(() => _openCashDrawer = v)),
            _SwitchTile("Disconnect after every print :", _disconnect, (v) => setState(() => _disconnect = v)),
            _SwitchTile("Auto-Cut after printing :", _autoCut, (v) => setState(() => _autoCut = v), showDivider: false),
          ]),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.print, color: kPrimaryColor),
            label: const Text("Add Printer", style: TextStyle(color: kPrimaryColor)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kPrimaryColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          _PrimaryButton(text: "Update", onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _DropdownTile(String label, String value, {bool showDivider = true}) {
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
                decoration: BoxDecoration(color: kBgColor, borderRadius: BorderRadius.circular(6)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    items: [DropdownMenuItem(value: value, child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.grey)))],
                    onChanged: (v) {},
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
  const FeatureSettingsPage({super.key});

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
                      // Markers 0 1 2 3 4
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
  const LanguagePage({super.key});

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

                    if(lang['tag'] == 'Beta')
                      Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                            child: const Text("Beta", style: TextStyle(color: Colors.white, fontSize: 10)),
                          )
                      )
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
// 7. BUSINESS DETAILS PAGE (Reused)
// ==========================================
class BusinessDetailsPage extends StatelessWidget {
  final String uid;
  const BusinessDetailsPage({super.key, required this.uid});
  // Placeholder implementation for context
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Business Details")), body: const Center(child: Text("Edit Business Details Here")));
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

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(color: kBgColor, borderRadius: BorderRadius.circular(8)),
      child: Center(child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400], size: 40)),
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