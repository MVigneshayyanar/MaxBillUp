import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';

// ==========================================
// CONSTANTS & STYLES
// ==========================================
const Color kPrimaryColor = Color(0xFF2196F3);
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
  bool _isCheckingVerifications = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Auto-check on load (gives time for UI to render first)
    Future.delayed(const Duration(seconds: 1), _checkAllPendingVerifications);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Automatically checks verification status for all pending users
  /// Uses the 'tempPassword' if available to check without staff interaction
  Future<void> _checkAllPendingVerifications() async {
    if (_isCheckingVerifications) return;

    setState(() => _isCheckingVerifications = true);

    FirebaseApp? tempApp;
    try {
      // 1. Get all pending users
      final snapshot = await _firestoreService.getStoreCollection('users').then((col) => col.get());

      final pendingDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Check if pending AND has a stored temp password we can use
        return (data['isEmailVerified'] == false) && (data['tempPassword'] != null);
      }).toList();

      if (pendingDocs.isEmpty) {
        return; // Nothing to check
      }

      // 2. Setup Temp App
      try {
        var existing = Firebase.app('AutoCheckApp');
        await existing.delete();
      } catch (_) {}

      tempApp = await Firebase.initializeApp(
          name: 'AutoCheckApp', options: Firebase.app().options);

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      int verifiedCount = 0;

      // 3. Loop and Check
      for (var doc in pendingDocs) {
        final data = doc.data() as Map<String, dynamic>;
        String email = data['email'] ?? '';
        String pass = data['tempPassword'] ?? '';

        if (email.isEmpty || pass.isEmpty) continue;

        try {
          final cred = await tempAuth.signInWithEmailAndPassword(email: email, password: pass);
          if (cred.user != null) {
            await cred.user!.reload();
            if (cred.user!.emailVerified) {
              // 4. Verified! Update DB and DELETE the temp password
              final updates = {
                'isEmailVerified': true,
                'verifiedAt': FieldValue.serverTimestamp(),
                'tempPassword': FieldValue.delete(), // Cleanup security risk
              };

              // Update Store Collection
              await _firestoreService.updateDocument('users', doc.id, updates);

              // Update Global Collection
              await FirebaseFirestore.instance.collection('users').doc(doc.id).update(updates).catchError((_) {});

              verifiedCount++;
            }
          }
          await tempAuth.signOut();
        } catch (e) {
          print("Check skipped for $email: $e");
        }
      }

      if (verifiedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("✅ Updated status for $verifiedCount staff member(s)"),
          backgroundColor: kSuccessColor,
        ));
      }

    } catch (e) {
      print("Auto-check error: $e");
    } finally {
      await tempApp?.delete();
      if (mounted) setState(() => _isCheckingVerifications = false);
    }
  }

  /// Advanced: Manually check status with password (fallback)
  Future<void> _manualCheckVerification(String staffId, String email, String? storedTempPass) async {
    String password = '';

    if (storedTempPass != null && storedTempPass.isNotEmpty) {
      password = storedTempPass;
    } else {
      // Ask Admin for the password if we don't have it stored
      final result = await showDialog<String>(
          context: context,
          builder: (context) {
            final passCtrl = TextEditingController();
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.lock_outline, color: kPrimaryColor),
                  SizedBox(width: 8),
                  const Text("Check Verification"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Enter the staff's temporary password to check their status."),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, passCtrl.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Check", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
      );
      if (result == null || result.isEmpty) return;
      password = result;
    }

    _showLoading(true);

    FirebaseApp? tempApp;
    try {
      try {
        var existing = Firebase.app('ManualCheckApp');
        await existing.delete();
      } catch (_) {}

      tempApp = await Firebase.initializeApp(name: 'ManualCheckApp', options: Firebase.app().options);
      final cred = await FirebaseAuth.instanceFor(app: tempApp)
          .signInWithEmailAndPassword(email: email, password: password);

      await cred.user?.reload();
      bool isVerified = cred.user?.emailVerified ?? false;

      if (isVerified) {
        final updates = {
          'isEmailVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
          'tempPassword': FieldValue.delete(), // Cleanup
        };

        // Update Store
        await _firestoreService.updateDocument('users', staffId, updates);

        // Update Global
        await FirebaseFirestore.instance.collection('users').doc(staffId).update(updates).catchError((_) {});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Verified! You can now approve.'), backgroundColor: kSuccessColor));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Not verified yet.'), backgroundColor: kWarningColor));
        }
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: kErrorColor));
    } finally {
      await tempApp?.delete();
      _showLoading(false);
    }
  }

  void _showLoading(bool show) {
    if (show) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    } else {
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader
    }
  }

  /// Get store-scoped staff stream with real-time updates
  Stream<QuerySnapshot> _getStaffStream() {
    return _firestoreService
        .getStoreCollection('users')
        .then((collection) => collection
        .where('role', whereIn: ['staff', 'Staff', 'manager', 'Manager', 'Admin', 'admin'])
        .snapshots(includeMetadataChanges: true))
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
      appBar: AppBar(
        title: const Text(
          'Staff Management',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: _isCheckingVerifications
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Status',
            onPressed: _isCheckingVerifications ? null : _checkAllPendingVerifications,
          )
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
                      tempPassword: data['tempPassword'], // Retrieve hidden temp password
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
        String? tempPassword,
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
      statusText = "Pending Verification";
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

                      // Action Buttons Logic
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
                        SizedBox(
                          height: 28,
                          child: OutlinedButton.icon(
                            onPressed: () => _manualCheckVerification(staffId, email, tempPassword),
                            icon: const Icon(Icons.refresh, size: 12),
                            label: const Text("Status", style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      )
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
            _buildHelpStep('Check email inbox (and Spam folder)'),
            _buildHelpStep('Click the verification link'),
            const SizedBox(height: 16),
            const Text(
              'Once they click the link, click the Refresh button in the top right of this screen.',
              style: TextStyle(fontSize: 12, color: kTextPrimary),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    "Staff will be invited via email. You can approve them here once they verify their email address.",
                    style: TextStyle(fontSize: 12, color: kTextPrimary),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(nameController, 'Full Name', Icons.person_outline),
                const SizedBox(height: 12),
                _buildTextField(phoneController, 'Phone', Icons.phone_outlined, type: TextInputType.phone),
                const SizedBox(height: 12),
                _buildTextField(emailController, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildTextField(passwordController, 'Temporary Password', Icons.lock_outline, isPassword: true),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  items: ['Staff', 'Manager', 'Admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setState(() => selectedRole = v!),
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
      }

      final storeId = await _firestoreService.getCurrentStoreId();
      if (storeId == null) throw Exception('Store ID not found');

      // IMPORTANT: Data to be synced to BOTH Store Collection and Global Collection
      Map<String, dynamic> userData = {
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'uid': cred.user!.uid,
        'storeId': storeId,
        'role': role,
        'isActive': false,
        'isEmailVerified': false,
        'tempPassword': passCtrl.text.trim(), // Stored temporarily until verification
        'permissions': _getDefaultPermissions(role),
        'createdAt': FieldValue.serverTimestamp(),
        'invitedBy': widget.uid,
      };

      // 1. Add to Store-Scoped Collection (for Staff Management UI)
      await _firestoreService.setDocument('users', cred.user!.uid, userData);

      // 2. Add to Global Root Collection (for Login syncing)
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set(userData);

      if (context.mounted) {
        Navigator.pop(context); // Close loader
        Navigator.pop(context); // Close dialog

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Invite sent! You can refresh status here.'),
            backgroundColor: kSuccessColor,
            duration: Duration(seconds: 4),
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      if(context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error'), backgroundColor: kErrorColor));
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
                final updates = {
                  'name': nameController.text.trim(),
                  'role': selectedRole,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                try {
                  // Update Store
                  await _firestoreService.updateDocument('users', staffId, updates);
                  // Update Global
                  await FirebaseFirestore.instance.collection('users').doc(staffId).update(updates).catchError((_) {});

                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  // handle error
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
                  final updates = {
                    'permissions': permissions,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };
                  // Update Store
                  await _firestoreService.updateDocument('users', staffId, updates);
                  // Update Global
                  await FirebaseFirestore.instance.collection('users').doc(staffId).update(updates).catchError((_) {});

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

  void _activateStaff(String staffId) async {
    final updates = {
      'isActive': true,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': widget.uid,
    };

    // Update Store
    await _firestoreService.updateDocument('users', staffId, updates);

    // Update Global
    await FirebaseFirestore.instance.collection('users').doc(staffId).update(updates).catchError((_) {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Staff activated! They can now log in.'), backgroundColor: kSuccessColor),
      );
    }
  }

  void _toggleStaffStatus(String staffId, bool newStatus) async {
    final updates = {'isActive': newStatus};

    // Update Store
    await _firestoreService.updateDocument('users', staffId, updates);
    // Update Global
    await FirebaseFirestore.instance.collection('users').doc(staffId).update(updates).catchError((_) {});
  }

  void _showDeleteConfirmation(BuildContext context, String staffId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff'),
        content: Text('Remove $name? They will not be able to login.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              // Delete from Store
              await _firestoreService.deleteDocument('users', staffId);
              // Delete from Global
              await FirebaseFirestore.instance.collection('users').doc(staffId).delete().catchError((_) {});

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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${isActive ? "Active" : "Inactive"}'),
            Text('Role: $role'),
            Text('Email: $email'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
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

