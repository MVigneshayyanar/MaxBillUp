import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:maxbillup/utils/firestore_service.dart';

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
const Color kWarningColor = Color(0xFFFF9500); // Used for "Pending Approval"
const Color kInvitedColor = Color(0xFF8E8E93); // Grey for "Invited/Not Verified"

class StaffManagementPage extends StatefulWidget {
  final String uid; // Current Admin's UID
  final String? userEmail; // Added parameter to fix error in Menu.dart
  final VoidCallback onBack;

  const StaffManagementPage({
    super.key,
    required this.uid,
    this.userEmail, // Added parameter
    required this.onBack,
  });

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Get store-scoped staff stream
  Stream<QuerySnapshot> _getStaffStream() async* {
    try {
      final collection = await _firestoreService.getStoreCollection('users');
      yield* collection
          .where('role', whereIn: ['staff', 'Staff', 'manager', 'Manager', 'Admin', 'admin'])
          .snapshots();
    } catch (e) {
      print('Error getting staff stream: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Staff Management',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kPrimaryColor),
          onPressed: widget.onBack,
        ),
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
                if (snapshot.connectionState == ConnectionState.waiting) {
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

    // Determine Display Status
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
                    // Avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: roleColor.withOpacity(0.1),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: roleColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
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
                    // Menu
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
                        const Text(
                          "Waiting for verification...",
                          style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: kTextSecondary),
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
        // Only allow manual activation if verified, OR force it if needed
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
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: kErrorColor, size: 20),
              const SizedBox(width: 12),
              Text('Remove Staff', style: TextStyle(color: kErrorColor)),
            ],
          ),
        ),
      ],
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
                  "The staff member will receive an email to verify their account. Once verified, you must approve them here to allow login.",
                  style: TextStyle(fontSize: 12, color: kTextSecondary),
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

    // 1. Basic Validation
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
      // 2. Create User in Auth using Secondary App (To not logout Admin)
      try {
        var existingApp = Firebase.app('SecondaryApp');
        await existingApp.delete();
      } catch (_) {}

      tempApp = await Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);
      UserCredential cred = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());

      // 3. Send Verification Email
      if (cred.user != null) {
        await cred.user!.sendEmailVerification();
        await cred.user!.updateDisplayName(nameCtrl.text.trim());
      }

      // 4. Create Firestore Document in store-scoped users collection (INACTIVE BY DEFAULT)
      final storeId = await _firestoreService.getCurrentStoreId();
      if (storeId == null) {
        throw Exception('Unable to determine store ID');
      }

      // Write to store-scoped users collection
      await _firestoreService.setDocument('users', cred.user!.uid, {
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'uid': cred.user!.uid,
        'storeId': storeId,
        'role': role,
        'isActive': false, // <--- CRITICAL: FALSE until Admin approves
        'isEmailVerified': false, // Will be updated when staff attempts login
        'permissions': _getDefaultPermissions(role),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context); // Close loader
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Invite sent to ${emailCtrl.text}. Waiting for verification.'),
          backgroundColor: kSuccessColor,
        ));
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

                  // Try updating Auth display name if it matches current user (otherwise requires cloud function)
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
    // Map current permissions to check against
    Map<String, bool> permissions = {
      // Menu Items
      'quotation': currentPermissions['quotation'] ?? false,
      'billHistory': currentPermissions['billHistory'] ?? false,
      'creditNotes': currentPermissions['creditNotes'] ?? false,
      'customerManagement': currentPermissions['customerManagement'] ?? false,
      'expenses': currentPermissions['expenses'] ?? false,
      'creditDetails': currentPermissions['creditDetails'] ?? false,
      'staffManagement': currentPermissions['staffManagement'] ?? false,

      // Report Items
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

      // Stock Items
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
    });
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

  // Helper Widgets
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
    // Default Map matching the reference structure
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