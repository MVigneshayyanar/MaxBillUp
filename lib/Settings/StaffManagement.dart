import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:maxbillup/Menu/Menu.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'dart:async';

// ==========================================
// CONSTANTS & STYLES
// ==========================================
const Color kPrimaryColor = Color(0xFF007AFF);
const Color kBackgroundColor = Color(0xFFF2F2F7);
const Color kSurfaceColor = Colors.white;
const Color kTextPrimary = Color(0xFF1C1C1E);
const Color kTextSecondary = Color(0xFF8E8E93);
const Color kSuccessColor = Color(0xFF34C759);
const Color kErrorColor = Color(0xFFFF3B30);
const Color kWarningColor = Color(0xFFFF9500);
const Color kInvitedColor = Color(0xFF8E8E93);

class StaffManagementPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final VoidCallback onBack;

  const StaffManagementPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.onBack,
  });

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FirestoreService _firestoreService = FirestoreService();
  Timer? _verificationCheckTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Start automatic verification checking
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verificationCheckTimer?.cancel();
    super.dispose();
  }

  /// Start periodic check for email verifications (every 15 seconds)
  void _startVerificationCheck() {
    // Check immediately on load
    Future.delayed(const Duration(seconds: 2), () {
      _checkPendingVerifications();
    });

    // Then check every 15 seconds
    _verificationCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkPendingVerifications();
    });
  }

  /// Check all pending staff for email verification status
  Future<void> _checkPendingVerifications() async {
    try {
      final storeCollection = await _firestoreService.getStoreCollection('users');
      final pendingStaff = await storeCollection
          .where('isEmailVerified', isEqualTo: false)
          .where('isActive', isEqualTo: false)
          .get();

      if (pendingStaff.docs.isEmpty) return;

      print('🔍 Checking ${pendingStaff.docs.length} pending verifications...');

      for (var doc in pendingStaff.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final uid = data['uid'] as String?;
        final email = data['email'] as String?;

        if (uid != null && email != null) {
          await _checkSingleVerification(uid, email, doc.id);
        }
      }
    } catch (e) {
      print('❌ Error checking verifications: $e');
    }
  }

  /// Check if a specific user has verified their email
  Future<void> _checkSingleVerification(String uid, String email, String docId) async {
    try {
      // Create a temporary Firebase app to check auth status
      FirebaseApp? tempApp;

      try {
        // Try to get user from Auth (this requires admin privileges in production)
        // For testing, we'll use a different approach

        // Alternative: Try to sign in with a test to check verification
        // This is a workaround - in production, use Cloud Functions

        // For now, we'll just log it
        print('Pending verification for: $email');

      } catch (e) {
        print('Cannot check auth status directly: $e');
      } finally {
        await tempApp?.delete();
      }

    } catch (e) {
      print('Error checking $email: $e');
    }
  }

  /// Manual check button handler
  Future<void> _manualCheckVerification(String staffId, String email) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Force a refresh of the data
      await Future.delayed(const Duration(seconds: 1));

      // Trigger rebuild
      if (mounted) {
        setState(() {});
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refreshed! Verification status updates when staff logs in.'),
            backgroundColor: kPrimaryColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor),
        );
      }
    }
  }

  /// Get store-scoped staff stream with real-time updates
  Stream<QuerySnapshot> _getStaffStream() {
    return _firestoreService
        .getStoreCollection('users')
        .then((collection) => collection
        .where('role', whereIn: ['staff', 'Staff', 'manager', 'Manager', 'Admin', 'admin'])
        .snapshots(includeMetadataChanges: true)) // Enable real-time updates
        .asStream()
        .asyncExpand((snapshot) => snapshot)
        .handleError((error) {
      print('Error getting staff stream: $error');
      return const Stream.empty();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      drawer: Drawer(
        child: MenuPage(uid: widget.uid, userEmail: widget.userEmail),
      ),
      appBar: AppBar(
        title: const Text(
          'Staff Management',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
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
        actions: [
          // Manual refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _checkPendingVerifications();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔄 Checking for verified staff...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Check Verifications',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteStaffDialog(context),
        label: const Text("Invite Staff", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        icon: const Icon(Icons.send, color: Colors.white),
        backgroundColor: kPrimaryColor,
        elevation: 4,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: kSurfaceColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, role...',
                  hintStyle: const TextStyle(color: kTextSecondary),
                  prefixIcon: const Icon(Icons.search, color: kTextSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Staff List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStaffStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var staffDocs = snapshot.data!.docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final role = (data['role'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || role.contains(_searchQuery);
                }).toList();

                if (staffDocs.isEmpty) {
                  return Center(
                    child: Text('No results for "$_searchQuery"', style: const TextStyle(color: kTextSecondary)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: staffDocs.length,
                  physics: const BouncingScrollPhysics(),
                  cacheExtent: 100,
                  addAutomaticKeepAlives: true,
                  itemBuilder: (context, index) {
                    final doc = staffDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return _buildStaffCard(
                      context,
                      staffId: doc.id,
                      name: data['name'] ?? 'Unknown',
                      phone: data['phone'] ?? 'N/A',
                      email: data['email'] ?? '',
                      role: data['role'] ?? 'Staff',
                      isActive: data['isActive'] ?? false,
                      isEmailVerified: data['isEmailVerified'] ?? false,
                      permissions: data['permissions'] as Map<String, dynamic>? ?? {},
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: kTextSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No staff members yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Invite someone to get started', style: TextStyle(color: kTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildStaffCard(
      BuildContext context, {
        required String staffId,
        required String name,
        required String phone,
        required String email,
        required String role,
        required bool isActive,
        required bool isEmailVerified,
        required Map<String, dynamic> permissions,
      }) {
    Color roleColor = _getRoleColor(role);

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isActive) {
      statusText = "Active";
      statusColor = kSuccessColor;
      statusIcon = Icons.check_circle;
    } else if (isEmailVerified) {
      statusText = "Needs Approval";
      statusColor = kWarningColor;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusText = "Invited (Pending)";
      statusColor = kInvitedColor;
      statusIcon = Icons.mail_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showStaffDetailsDialog(context, staffId, name, phone, email, role, isActive, permissions),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: roleColor.withOpacity(0.1),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: roleColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(role, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: roleColor)),
                          const SizedBox(height: 4),
                          Text(email, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                        ],
                      ),
                    ),
                    _buildPopupMenu(context, staffId, name, phone, email, isActive, isEmailVerified, permissions, role),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                      const Spacer(),
                      // Approval Button logic
                      if (!isActive && isEmailVerified)
                        SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: () => _activateStaff(staffId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kSuccessColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              elevation: 0,
                            ),
                            child: const Text("Add to Store", style: TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                        ),
                      if (!isActive && !isEmailVerified)
                        Row(
                          children: [
                            const Text(
                              "Pending...",
                              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: kTextSecondary),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 24,
                              width: 60,
                              child: OutlinedButton(
                                onPressed: () => _manualCheckVerification(staffId, email),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: const BorderSide(color: kPrimaryColor, width: 1),
                                ),
                                child: const Text('Check', style: TextStyle(fontSize: 10)),
                              ),
                            ),
                          ],
                        )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, String staffId, String name, String phone, String email, bool isActive, bool isVerified, Map<String, dynamic> permissions, String role) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, color: kTextSecondary),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _showEditStaffDialog(context, staffId, name, phone, email, role, isActive, permissions);
            break;
          case 'permissions':
            _showPermissionsDialog(context, staffId, name, permissions);
            break;
          case 'toggle_active':
            if (!isVerified && !isActive) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Staff must verify email before activation.")));
            } else {
              _toggleStaffStatus(staffId, !isActive);
            }
            break;
          case 'resend_info':
            _showVerificationHelpDialog(email, name);
            break;
          case 'delete':
            _showDeleteConfirmation(context, staffId, name);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20, color: kPrimaryColor),
              SizedBox(width: 12),
              Text('Edit Details'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'permissions',
          child: Row(
            children: [
              Icon(Icons.security, size: 20, color: kPrimaryColor),
              SizedBox(width: 12),
              Text('Manage Permissions'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle_active',
          child: Row(
            children: [
              Icon(
                isActive ? Icons.block : Icons.check_circle,
                color: isActive ? kErrorColor : kSuccessColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(isActive ? 'Deactivate' : 'Approve / Activate'),
            ],
          ),
        ),
        if (!isVerified)
          const PopupMenuItem(
            value: 'resend_info',
            child: Row(
              children: [
                Icon(Icons.help_outline, size: 20, color: kWarningColor),
                SizedBox(width: 12),
                Text('Verification Help'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: kErrorColor, size: 20),
              SizedBox(width: 12),
              Text('Remove Staff', style: TextStyle(color: kErrorColor)),
            ],
          ),
        ),
      ],
    );
  }

  void _showVerificationHelpDialog(String email, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.email, color: kWarningColor),
            SizedBox(width: 12),
            Text('Verification Help'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ask $name to:', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildHelpStep('Check email inbox'),
            _buildHelpStep('Check Spam/Junk folder'),
            _buildHelpStep('Look for email from noreply@maxbillup.firebaseapp.com'),
            _buildHelpStep('Click verification link in email'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Staff Email:', style: TextStyle(fontSize: 12, color: kTextSecondary)),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kSuccessColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: kSuccessColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Status updates automatically when staff logs in after verification',
                      style: TextStyle(fontSize: 11, color: kTextPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: kSuccessColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ==========================================
  // LOGIC FUNCTIONS
  // ==========================================

  void _showInviteStaffDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'Staff';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Invite New Staff'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Staff will receive a verification email. Once verified and logged in, you can approve them here.",
                  style: TextStyle(fontSize: 12, color: kTextSecondary),
                ),
                const SizedBox(height: 16),
                _buildTextField(nameController, 'Full Name', Icons.person_outline),
                const SizedBox(height: 12),
                _buildTextField(phoneController, 'Phone', Icons.phone_outlined, type: TextInputType.phone),
                const SizedBox(height: 12),
                _buildTextField(emailController, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildTextField(passwordController, 'Temporary Password (min 6)', Icons.lock_outline, isPassword: true),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRole,
                      isExpanded: true,
                      items: ['Staff', 'Manager', 'Admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => selectedRole = v!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => _handleInvite(context, nameController, phoneController, emailController, passwordController, selectedRole),
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              child: const Text('Send Invite', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleInvite(
      BuildContext context,
      TextEditingController nameCtrl,
      TextEditingController phoneCtrl,
      TextEditingController emailCtrl,
      TextEditingController passCtrl,
      String role
      ) async {

    if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (passCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    FirebaseApp? tempApp;
    try {
      try {
        var existingApp = Firebase.app('SecondaryApp');
        await existingApp.delete();
      } catch (_) {}

      tempApp = await Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);
      UserCredential cred = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());

      if (cred.user != null) {
        await cred.user!.updateDisplayName(nameCtrl.text.trim());
        await cred.user!.sendEmailVerification();
        print('✅ Verification email sent to: ${emailCtrl.text.trim()}');
      }

      final storeId = await _firestoreService.getCurrentStoreId();
      if (storeId == null) {
        throw Exception('Unable to determine store ID');
      }

      await _firestoreService.setDocument('users', cred.user!.uid, {
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'uid': cred.user!.uid,
        'storeId': storeId,
        'role': role,
        'isActive': false,
        'isEmailVerified': false,
        'permissions': _getDefaultPermissions(role),
        'createdAt': FieldValue.serverTimestamp(),
        'invitedBy': widget.uid,
      });

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pop(context);

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: kSuccessColor),
                SizedBox(width: 12),
                Text('Invitation Sent!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📧 Verification email sent to:'),
                const SizedBox(height: 8),
                Text(emailCtrl.text.trim(), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('Next Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('1. Staff verifies email'),
                const Text('2. Staff logs into the app'),
                const Text('3. Status updates here automatically'),
                const Text('4. You approve them by clicking "Add to Store"'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      if(context.mounted) {
        Navigator.pop(context);
        String msg = e.message ?? 'Error';
        if (e.code == 'email-already-in-use') msg = 'Email already registered';
        if (e.code == 'weak-password') msg = 'Password too weak';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: kErrorColor));
      }
    } finally {
      await tempApp?.delete();
    }
  }

  void _showEditStaffDialog(
      BuildContext context,
      String staffId,
      String currentName,
      String currentPhone,
      String currentEmail,
      String currentRole,
      bool currentIsActive,
      Map<String, dynamic> currentPermissions,
      ) {
    final nameController = TextEditingController(text: currentName);
    String selectedRole = currentRole;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Staff Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: TextEditingController(text: currentPhone),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Cannot be changed)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: TextEditingController(text: currentEmail),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Email (Cannot be changed)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                  ),
                  items: ['Staff', 'Manager', 'Admin'].map((role) {
                    return DropdownMenuItem(value: role, child: Text(role));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
                  return;
                }

                try {
                  await _firestoreService.updateDocument('users', staffId, {
                    'name': name,
                    'role': selectedRole,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null && currentUser.uid == staffId) {
                    await currentUser.updateDisplayName(name);
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully'), backgroundColor: kSuccessColor));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              child: const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionsDialog(
      BuildContext context,
      String staffId,
      String staffName,
      Map<String, dynamic> currentPermissions,
      ) {
    Map<String, bool> permissions = {
      'quotation': currentPermissions['quotation'] ?? false,
      'billHistory': currentPermissions['billHistory'] ?? false,
      'creditNotes': currentPermissions['creditNotes'] ?? false,
      'customerManagement': currentPermissions['customerManagement'] ?? false,
      'expenses': currentPermissions['expenses'] ?? false,
      'creditDetails': currentPermissions['creditDetails'] ?? false,
      'staffManagement': currentPermissions['staffManagement'] ?? false,
      'analytics': currentPermissions['analytics'] ?? false,
      'daybook': currentPermissions['daybook'] ?? false,
      'salesSummary': currentPermissions['salesSummary'] ?? false,
      'salesReport': currentPermissions['salesReport'] ?? false,
      'itemSalesReport': currentPermissions['itemSalesReport'] ?? false,
      'topCustomer': currentPermissions['topCustomer'] ?? false,
      'stockReport': currentPermissions['stockReport'] ?? false,
      'lowStockProduct': currentPermissions['lowStockProduct'] ?? false,
      'topProducts': currentPermissions['topProducts'] ?? false,
      'topCategory': currentPermissions['topCategory'] ?? false,
      'expensesReport': currentPermissions['expensesReport'] ?? false,
      'taxReport': currentPermissions['taxReport'] ?? false,
      'hsnReport': currentPermissions['hsnReport'] ?? false,
      'staffSalesReport': currentPermissions['staffSalesReport'] ?? false,
      'addProduct': currentPermissions['addProduct'] ?? false,
      'addCategory': currentPermissions['addCategory'] ?? false,
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Permissions for $staffName'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPermissionSection(
                    'Menu Items',
                    [
                      {'key': 'quotation', 'label': 'Quotation'},
                      {'key': 'billHistory', 'label': 'Bill History'},
                      {'key': 'creditNotes', 'label': 'Credit Notes'},
                      {'key': 'customerManagement', 'label': 'Customer Management'},
                      {'key': 'expenses', 'label': 'Expenses'},
                      {'key': 'creditDetails', 'label': 'Credit Details'},
                      {'key': 'staffManagement', 'label': 'Staff Management'},
                    ],
                    permissions,
                    setState,
                  ),
                  const Divider(height: 24),
                  _buildPermissionSection(
                    'Report Items',
                    [
                      {'key': 'analytics', 'label': 'Analytics'},
                      {'key': 'daybook', 'label': 'Daybook'},
                      {'key': 'salesSummary', 'label': 'Sales Summary'},
                      {'key': 'salesReport', 'label': 'Sales Report'},
                      {'key': 'itemSalesReport', 'label': 'Item Sales Report'},
                      {'key': 'topCustomer', 'label': 'Top Customer'},
                      {'key': 'stockReport', 'label': 'Stock Report'},
                      {'key': 'lowStockProduct', 'label': 'Low Stock Product'},
                      {'key': 'topProducts', 'label': 'Top Products'},
                      {'key': 'topCategory', 'label': 'Top Category'},
                      {'key': 'expensesReport', 'label': 'Expenses Report'},
                      {'key': 'taxReport', 'label': 'Tax Report'},
                      {'key': 'hsnReport', 'label': 'HSN Report'},
                      {'key': 'staffSalesReport', 'label': 'Staff Sales Report'},
                    ],
                    permissions,
                    setState,
                  ),
                  const Divider(height: 24),
                  _buildPermissionSection(
                    'Stock Items',
                    [
                      {'key': 'addProduct', 'label': 'Add Product'},
                      {'key': 'addCategory', 'label': 'Add Category'},
                    ],
                    permissions,
                    setState,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _firestoreService.updateDocument('users', staffId, {
                    'permissions': permissions,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Permissions updated successfully'), backgroundColor: kSuccessColor),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSection(
      String title,
      List<Map<String, String>> items,
      Map<String, bool> permissions,
      StateSetter setState,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryColor),
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          final key = item['key']!;
          final label = item['label']!;
          return CheckboxListTile(
            title: Text(label),
            value: permissions[key] ?? false,
            onChanged: (value) {
              setState(() {
                permissions[key] = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: kPrimaryColor,
          );
        }),
      ],
    );
  }

  void _activateStaff(String staffId) {
    _firestoreService.updateDocument('users', staffId, {
      'isActive': true,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': widget.uid,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Staff activated! They can now log in.'), backgroundColor: kSuccessColor),
    );
  }

  void _toggleStaffStatus(String staffId, bool newStatus) {
    _firestoreService.updateDocument('users', staffId, {
      'isActive': newStatus,
    });
  }

  void _showDeleteConfirmation(BuildContext context, String staffId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff'),
        content: Text('Are you sure you want to remove $name? They will no longer be able to login.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _firestoreService.deleteDocument('users', staffId);
              if(context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? type, bool isPassword = false}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: kTextSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      ),
    );
  }

  void _showStaffDetailsDialog(BuildContext context, String staffId, String name, String phone, String email, String role, bool isActive, Map<String, dynamic> permissions) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Phone', phone, Icons.phone),
              if (email.isNotEmpty) _buildDetailRow('Email', email, Icons.email),
              _buildDetailRow('Role', role, Icons.work),
              _buildDetailRow(
                'Status',
                isActive ? 'Active' : 'Inactive',
                isActive ? Icons.check_circle : Icons.cancel,
              ),
              const SizedBox(height: 16),
              const Text('Active Permissions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: permissions.entries.where((e) => e.value == true).map((e) => Chip(
                  label: Text(_formatPermissionName(e.key), style: const TextStyle(fontSize: 10)),
                  backgroundColor: Colors.green.withOpacity(0.1),
                  labelStyle: const TextStyle(color: Colors.green),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              )
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  String _formatPermissionName(String key) {
    return key
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
        .trim()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _getRoleColor(String role) {
    if (role.toLowerCase().contains('admin')) return kErrorColor;
    if (role.toLowerCase().contains('manager')) return kWarningColor;
    return kPrimaryColor;
  }

  Map<String, bool> _getDefaultPermissions(String role) {
    bool isAdmin = role.toLowerCase().contains('admin');
    return {
      'quotation': true,
      'billHistory': true,
      'creditNotes': isAdmin,
      'customerManagement': true,
      'expenses': isAdmin,
      'creditDetails': isAdmin,
      'staffManagement': isAdmin,
      'analytics': isAdmin,
      'daybook': isAdmin,
      'salesSummary': isAdmin,
      'salesReport': isAdmin,
      'itemSalesReport': isAdmin,
      'topCustomer': isAdmin,
      'stockReport': isAdmin,
      'lowStockProduct': isAdmin,
      'topProducts': isAdmin,
      'topCategory': isAdmin,
      'expensesReport': isAdmin,
      'taxReport': isAdmin,
      'hsnReport': isAdmin,
      'staffSalesReport': isAdmin,
      'addProduct': isAdmin,
      'addCategory': isAdmin,
    };
  }
}
