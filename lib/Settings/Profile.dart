import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/Menu/Menu.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/Auth/LoginPage.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maxbillup/Auth/SubscriptionPlanPage.dart';
import 'package:maxbillup/utils/firestore_service.dart';

// ==========================================
// CONSTANTS & STYLES (MATCHED TO UI IMAGE)
// ==========================================
const Color kPrimaryColor = Color(0xFF007AFF); // Vibrant Blue from Header/Buttons
const Color kBgColor = Color(0xFFF5F7FA);     // Cool Light Grey Background
const Color kSurfaceColor = Colors.white;     // Card/Container White
const Color kInputFillColor = Color(0xFFF2F4F7); // Light Grey for TextFields
const Color kDangerColor = Color(0xFFFF3B30);
const Color kTextPrimary = Color(0xFF1D1D1D); // Dark text
const Color kTextSecondary = Color(0xFF8A8A8E); // Grey text

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
  bool _isLoading = true;

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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

    switch (_currentView) {
      case 'BusinessDetails':
        return BusinessDetailsPage(uid: widget.uid, onBack: _goBack);
      case 'ReceiptSettings':
        return ReceiptSettingsPage(
          onBack: _goBack,
          onNavigate: _navigateTo,
          uid: widget.uid,
          userEmail: widget.userEmail,
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

    return Scaffold(
      backgroundColor: kBgColor,
      drawer: Drawer(
        child: MenuPage(uid: widget.uid, userEmail: widget.userEmail),
      ),
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: kPrimaryColor, // Matches the blue header in image
        elevation: 0,
        leading: Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final tabHeight = kToolbarHeight;
              return GestureDetector(
                onTap: () {
                  Scaffold.of(context).openDrawer();
                },
                child: Container(
                  width: screenWidth * 0.12,
                  height: tabHeight,
                  child: Icon(
                    Icons.menu,
                    color: const Color(0xFFffffff),
                    size: screenWidth * 0.06,
                  ),
                ),
              );
            }
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
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
            _SettingsTile(icon: Icons.store_mall_directory_outlined, title: "Business Details", onTap: () => _navigateTo('BusinessDetails')),
            _SettingsTile(icon: Icons.receipt_long_outlined, title: "Receipt", onTap: () => _navigateTo('ReceiptSettings')),
            _SettingsTile(icon: Icons.percent_outlined, title: "TAX / WAT", onTap: () => _navigateTo('TaxSettings')),
            _SettingsTile(icon: Icons.print_outlined, title: "Printer Setup", onTap: () => _navigateTo('PrinterSetup')),
            _SettingsTile(icon: Icons.tune_outlined, title: "Feature Settings", onTap: () => _navigateTo('FeatureSettings')),
            _SettingsTile(icon: Icons.language_outlined, title: "Languages", onTap: () => _navigateTo('Language')),
            _SettingsTile(icon: Icons.dark_mode_outlined, title: "Theme", showDivider: false, onTap: () => _navigateTo('Theme')),
          ]),
          const SizedBox(height: 24),
          _buildSectionTitle("Support & Service"),
          _SettingsGroup(children: [
            _SettingsTile(icon: Icons.help_outline, title: "Help", onTap: () => _navigateTo('Help')),
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
      // bottomNavigationBar: CommonBottomNav(
      //   uid: widget.uid,
      //   userEmail: widget.userEmail,
      //   currentIndex: 4,
      //   screenWidth: screenWidth,
      // ),
    );
  }

  Widget _buildProfileCard() {
    final name = _storeData?['businessName'] ?? _userData?['businessName'] ?? _userData?['name'] ?? 'User';
    final email = _userData?['email'] ?? widget.userEmail ?? '';
    final role = _userData?['role'] ?? 'Administrator';
    final plan = _storeData?['plan'] ?? _userData?['plan'] ?? 'Free';
    final expiry = _storeData?['subscriptionExpiryDate'] ?? _userData?['subscriptionExpiryDate'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kSurfaceColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: kBgColor,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : "U", style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.workspace_premium, size: 10, color: Colors.orange.shade800),
                          const SizedBox(width: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(plan, style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                              if (expiry != null)
                                Text(
                                  _formatExpiry(expiry.toString()),
                                  style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: plan == 'Max'
                      ? null
                      : () {
                    Navigator.pushReplacement(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => SubscriptionPlanPage(
                          uid: _userData?['uid'] ?? widget.uid,
                          currentPlan: plan,
                        ),
                      ),
                    );
                  },
                  child: const Text('Upgrade Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(role, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kPrimaryColor)),
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
          Navigator.of(context).pushAndRemoveUntil(CupertinoPageRoute(builder: (_) => const LoginPage()), (r) => false);
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kDangerColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: Colors.white,
        ),
        child: const Text("Logout", style: TextStyle(color: kDangerColor, fontSize: 16)),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
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
// 4. PRINTER SETUP PAGE (BLUETOOTH)
// ==========================================
class PrinterSetupPage extends StatefulWidget {
  final VoidCallback onBack;
  const PrinterSetupPage({super.key, required this.onBack});
  @override
  State<PrinterSetupPage> createState() => _PrinterSetupPageState();
}

class _PrinterSetupPageState extends State<PrinterSetupPage> {
  bool _isLoading = false;
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enableAutoPrint = prefs.getBool('enable_auto_print') ?? true;
    final savedDeviceId = prefs.getString('selected_printer_id');
    setState(() {
      _enableAutoPrint = enableAutoPrint;
    });

    if (savedDeviceId != null) {
      _findSavedDevice(savedDeviceId);
    }
  }

  Future<void> _findSavedDevice(String deviceId) async {
    try {
      final devices = await FlutterBluePlus.bondedDevices;
      final device = devices.firstWhere(
            (d) => d.remoteId.toString() == deviceId,
        orElse: () => devices.first,
      );
      if (mounted) {
        setState(() {
          _selectedDevice = device;
        });
      }
    } catch (e) {
      // Device not found
    }
  }

  Future<void> _initPrinter() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _showBluetoothDialog();
        return;
      }
    } catch (e) {
      // Bluetooth not available
    }

    final permissionStatus = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (permissionStatus[Permission.bluetoothScan]?.isGranted == true) {
      _getBondedDevices();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bluetooth permissions are required"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showBluetoothDialog() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enable Bluetooth"),
        content: const Text("Bluetooth is required to connect to printers. Would you like to enable it?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FlutterBluePlus.turnOn();
                await Future.delayed(const Duration(seconds: 2));
                _getBondedDevices();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enable Bluetooth manually from Settings")),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: const Text("Enable"),
          ),
        ],
      ),
    );
  }

  Future<void> _getBondedDevices() async {
    setState(() => _isLoading = true);
    try {
      final devices = await FlutterBluePlus.bondedDevices;
      if (mounted) {
        setState(() {
          _bondedDevices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error getting devices: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _scanForDevices() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _showBluetoothDialog();
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bluetooth not available"), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() {
      _isScanning = true;
      _scannedDevices.clear();
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        final devices = results.map((r) => r.device).toList();
        if (mounted) {
          setState(() {
            _scannedDevices = devices;
          });
        }
      });

      await Future.delayed(const Duration(seconds: 10));
      await subscription.cancel();
      await FlutterBluePlus.stopScan();

      if (mounted) {
        setState(() => _isScanning = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Scan error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDevice(BluetoothDevice device) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_printer_id', device.remoteId.toString());
      await prefs.setString('selected_printer_name', device.platformName);

      if (mounted) {
        setState(() {
          _selectedDevice = device;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Printer '${device.platformName}' selected successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error selecting printer: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_printer_id');
    await prefs.remove('selected_printer_name');
    if (mounted) {
      setState(() {
        _selectedDevice = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Printer removed"), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Printer Setup", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _getBondedDevices,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_selectedDevice != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Selected Printer",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          _selectedDevice!.platformName.isEmpty ? "Unknown Device" : _selectedDevice!.platformName,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                        Text(
                          _selectedDevice!.remoteId.toString(),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _removeDevice,
                    child: const Text("Remove", style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _scanForDevices,
            icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.bluetooth_searching),
            label: Text(_isScanning ? "Scanning..." : "Scan for Devices"),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),
          if (_bondedDevices.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.link, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  "Paired Devices",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _bondedDevices.map((device) {
                  final isSelected = _selectedDevice?.remoteId.toString() == device.remoteId.toString();
                  final deviceName = device.platformName.isEmpty ? "Unknown Device" : device.platformName;
                  return ListTile(
                    leading: Icon(
                      Icons.print,
                      color: isSelected ? kPrimaryColor : Colors.grey,
                    ),
                    title: Text(
                      deviceName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(device.remoteId.toString()),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : ElevatedButton(
                      onPressed: () => _selectDevice(device),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text("Select"),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_scannedDevices.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.bluetooth, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  "Nearby Devices",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Text(
              "Note: You may need to pair these devices first",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _scannedDevices.where((d) {
                  return !_bondedDevices.any((bd) => bd.remoteId == d.remoteId);
                }).map((device) {
                  final isSelected = _selectedDevice?.remoteId.toString() == device.remoteId.toString();
                  final deviceName = device.platformName.isEmpty ? "Unknown Device" : device.platformName;
                  return ListTile(
                    leading: Icon(
                      Icons.bluetooth,
                      color: isSelected ? kPrimaryColor : Colors.grey,
                    ),
                    title: Text(
                      deviceName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(device.remoteId.toString()),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : ElevatedButton(
                      onPressed: () => _selectDevice(device),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text("Select"),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!_isLoading && !_isScanning && _bondedDevices.isEmpty && _scannedDevices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      "No Bluetooth devices found",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Please pair your printer in Android Settings\nor tap 'Scan for Devices' to find nearby printers",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading && !_isScanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
          const SizedBox(height: 24),
          _SettingsGroup(children: [
            _SwitchTile("Enable Auto Print", _enableAutoPrint, (v) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('enable_auto_print', v);
              setState(() => _enableAutoPrint = v);
            }),
          ]),
        ],
      ),
    );
  }
}

// ==========================================
// OTHER SETTINGS PAGES
// ==========================================
class ReceiptSettingsPage extends StatelessWidget {
  final VoidCallback onBack;
  final Function(String) onNavigate;
  final String uid;
  final String? userEmail;

  const ReceiptSettingsPage({
    super.key,
    required this.onBack,
    required this.onNavigate,
    required this.uid,
    this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Receipt Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
              onTap: () => onNavigate('PrinterSetup'),
            ),
            _SettingsTile(
              title: "A4 Size / PDF",
              subtitle: "Customize the A4 Size",
              icon: Icons.picture_as_pdf,
              showDivider: false,
              onTap: () => onNavigate('ReceiptCustomization'),
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
        title: const Text("Receipt Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
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
        title: const Text("Tax Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
              decoration: BoxDecoration(color: kInputFillColor, borderRadius: BorderRadius.circular(8)),
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
                      setState(() {
                        t['active'] = v;
                      });
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

  Widget _TaxListTile(Map tax) {
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

  Widget _TaxSwitchTile(Map tax, Function(bool) onChanged) {
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
        title: const Text("Feature Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
        title: const Text("Choose Language", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                  color: isSelected ? kPrimaryColor.withOpacity(0.1) : kInputFillColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? kPrimaryColor : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(lang['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (lang['native']!.isNotEmpty) Text(lang['native']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    if (isSelected)
                      const Positioned(right: 0, top: 0, child: Icon(Icons.radio_button_checked, color: kPrimaryColor, size: 20))
                    else
                      Positioned(right: 0, top: 0, child: Icon(Icons.radio_button_off, color: Colors.grey.shade400, size: 20)),
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

class BusinessDetailsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;
  const BusinessDetailsPage({super.key, required this.uid, required this.onBack});
  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  bool _isLoading = true;
  String _role = 'staff';
  String? _storeId;
  String _businessName = '';
  String _ownerName = '';
  String _businessPhone = '';
  String _ownerPhone = '';
  String _email = '';
  String _address = '';
  String _gstin = '';
  String _ownerUid = '';
  String _createdAt = '';
  String _updatedAt = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(widget.uid).get();
      if (!userDoc.exists) throw Exception("User not found");
      final userData = userDoc.data()!;
      final role = userData['role'] ?? 'staff';
      final storeIdInt = userData['storeId'];
      final storeId = storeIdInt?.toString();

      if (storeId != null) {
        final storeDoc = await firestore.collection('store').doc(storeId).get();
        if (storeDoc.exists) {
          final storeData = storeDoc.data()!;
          setState(() {
            _businessName = storeData['businessName'] ?? '';
            _ownerName = storeData['ownerName'] ?? '';
            _businessPhone = storeData['businessPhone'] ?? '';
            _ownerPhone = storeData['ownerPhone'] ?? '';
            _email = storeData['ownerEmail'] ?? '';
            _address = storeData['address'] ?? '';
            _gstin = storeData['gstin'] ?? '';
            _ownerUid = storeData['ownerUid'] ?? '';
            if (storeData['createdAt'] != null) {
              final ts = storeData['createdAt'] as Timestamp;
              _createdAt = DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
            }
            if (storeData['updatedAt'] != null) {
              final ts = storeData['updatedAt'] as Timestamp;
              _updatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
            }
          });
        }
      }

      if (mounted) {
        setState(() {
          _role = role;
          _storeId = storeId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get isAdmin => _role.toLowerCase().contains('admin') || _role.toLowerCase().contains('manager');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Business Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !isAdmin
          ? _buildAccessDenied()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: kPrimaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Business details are synced from your account',
                      style: TextStyle(color: kPrimaryColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Business Information', Icons.business),
                  const SizedBox(height: 20),
                  _buildReadOnlyField('Business Name', Icons.store_mall_directory, _businessName),
                  const Divider(height: 32),
                  _buildReadOnlyField('Business Phone', Icons.phone_android, _businessPhone),
                  const Divider(height: 32),
                  _buildReadOnlyField('Store ID', Icons.qr_code, _storeId ?? 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Owner Information', Icons.person),
                  const SizedBox(height: 20),
                  _buildReadOnlyField('Owner Name', Icons.badge, _ownerName),
                  const Divider(height: 32),
                  _buildReadOnlyField('Email Address', Icons.email, _email),
                  const Divider(height: 32),
                  _buildReadOnlyField('Personal Phone', Icons.phone, _ownerPhone),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 24),
          const Text('Restricted Access', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: kPrimaryColor, size: 20),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, IconData icon, String value) {
    final isEmpty = value.isEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: isEmpty ? Colors.grey.shade400 : kPrimaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(isEmpty ? 'Not provided' : value,
                  style: TextStyle(fontSize: 15, color: isEmpty ? Colors.grey[400] : Colors.black87, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class ThemePage extends StatefulWidget {
  final VoidCallback onBack;
  const ThemePage({super.key, required this.onBack});
  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  String _selectedTheme = 'Light Mode';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Theme", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildThemeOption('Light Mode', 'Bright and clear', _selectedTheme == 'Light Mode', () => setState(() => _selectedTheme = 'Light Mode')),
            const SizedBox(height: 16),
            _buildThemeOption('Dark Mode', 'Easy on the eyes', _selectedTheme == 'Dark Mode', () => setState(() => _selectedTheme = 'Dark Mode')),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Theme updated to $_selectedTheme'), backgroundColor: kPrimaryColor));
                },
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Update', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
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
          border: Border.all(color: isSelected ? kPrimaryColor : Colors.grey.shade300, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey))
                ])),
            if (isSelected) const Icon(Icons.check, color: kPrimaryColor)
          ],
        ),
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  final VoidCallback onBack;
  final Function(String) onNavigate;
  const HelpPage({super.key, required this.onBack, required this.onNavigate});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text("Help", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHelpTile('FAQs', Icons.question_answer_outlined, () => onNavigate('FAQs')),
          const SizedBox(height: 12),
          _buildHelpTile('Upcoming Features', Icons.update_outlined, () => onNavigate('UpcomingFeatures')),
          const SizedBox(height: 12),
          _buildHelpTile('Video Tutorials', Icons.play_circle_outline, () => onNavigate('VideoTutorials')),
        ],
      ),
    );
  }

  Widget _buildHelpTile(String title, IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.black87),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class FAQsPage extends StatelessWidget {
  final VoidCallback onBack;
  const FAQsPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(title: const Text("FAQs", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), backgroundColor: kPrimaryColor, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack)),
      body: const Center(child: Text("FAQs Content Here")),
    );
  }
}

class UpcomingFeaturesPage extends StatelessWidget {
  final VoidCallback onBack;
  const UpcomingFeaturesPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(title: const Text("Upcoming Features", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), backgroundColor: kPrimaryColor, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack)),
      body: const Center(child: Text("Features Content Here")),
    );
  }
}

class VideoTutorialsPage extends StatelessWidget {
  final VoidCallback onBack;
  const VideoTutorialsPage({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(title: const Text("Video Tutorials", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), backgroundColor: kPrimaryColor, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack)),
      body: const Center(child: Text("Videos Content Here")),
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
      decoration: BoxDecoration(
        color: kInputFillColor,
        borderRadius: BorderRadius.circular(8), // Matches input field radius from image
      ),
      child: TextField(
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
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
      decoration: BoxDecoration(
        color: kInputFillColor, // Matches input style
        borderRadius: BorderRadius.circular(8),
      ),
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
          elevation: 0,
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}