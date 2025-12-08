import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==========================================
// STAFF MANAGEMENT PAGE
// ==========================================
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Staff Management',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF007AFF),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 28),
            onPressed: () => _showAddStaffDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search staff by name, phone, or role...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF007AFF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF007AFF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),

          // Staff List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', whereIn: ['staff', 'Staff', 'manager', 'Manager', 'Admin', 'admin', 'Administrator'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No staff members found',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first staff member',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                var staffDocs = snapshot.data!.docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  final role = (data['role'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      phone.contains(_searchQuery) ||
                      role.contains(_searchQuery);
                }).toList();

                if (staffDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'No results found for "$_searchQuery"',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: staffDocs.length,
                  itemBuilder: (context, index) {
                    final doc = staffDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final staffId = doc.id;
                    final name = data['name'] ?? 'Unknown';
                    final phone = data['phone'] ?? 'N/A';
                    final role = data['role'] ?? 'Staff';
                    final email = data['email'] ?? '';
                    final isActive = data['isActive'] ?? true;
                    final permissions = data['permissions'] as Map<String, dynamic>? ?? {};

                    return _buildStaffCard(
                      context,
                      staffId: staffId,
                      name: name,
                      phone: phone,
                      email: email,
                      role: role,
                      isActive: isActive,
                      permissions: permissions,
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

  Widget _buildStaffCard(
    BuildContext context, {
    required String staffId,
    required String name,
    required String phone,
    required String email,
    required String role,
    required bool isActive,
    required Map<String, dynamic> permissions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showStaffDetailsDialog(context, staffId, name, phone, email, role, isActive, permissions),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _getRoleColor(role).withOpacity(0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(role),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Staff Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getRoleColor(role).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              role,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getRoleColor(role),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.email, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                email,
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isActive ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: isActive ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isActive ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditStaffDialog(context, staffId, name, phone, email, role, isActive, permissions);
                        break;
                      case 'permissions':
                        _showPermissionsDialog(context, staffId, name, permissions);
                        break;
                      case 'toggle':
                        _toggleStaffStatus(staffId, !isActive);
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
                          Icon(Icons.edit, size: 20, color: Color(0xFF007AFF)),
                          SizedBox(width: 8),
                          Text('Edit Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'permissions',
                      child: Row(
                        children: [
                          Icon(Icons.security, size: 20, color: Color(0xFF007AFF)),
                          SizedBox(width: 8),
                          Text('Manage Permissions'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.block : Icons.check_circle,
                            size: 20,
                            color: isActive ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'Admin':
      case 'administrator':
        return Colors.red;
      case 'manager':
        return Colors.orange;
      default:
        return const Color(0xFF007AFF);
    }
  }

  void _showAddStaffDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'Staff';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Staff Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                    hintText: 'example@email.com',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    hintText: 'Minimum 6 characters',
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
                final phone = phoneController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text.trim();

                // Validate all required fields
                if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Validate email format
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid email address'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Validate password length
                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  // Check if phone already exists (using query now)
                  final existingPhone = await FirebaseFirestore.instance
                      .collection('users')
                      .where('phone', isEqualTo: phone)
                      .limit(1)
                      .get();

                  if (existingPhone.docs.isNotEmpty) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Phone number already exists'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  // Check if email already exists in Firestore (using query)
                  final existingEmail = await FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();

                  if (existingEmail.docs.isNotEmpty) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email already exists'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  // Create Firebase Authentication account
                  UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                    email: email,
                    password: password,
                  );

                  // Get the created user's UID
                  final authUid = userCredential.user!.uid;

                  // Update display name in Firebase Auth
                  await userCredential.user!.updateDisplayName(name);

                  // Get current user's storeId
                  final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
                  final storeId = currentUserDoc.data()?['storeId'];

                  // Default permissions based on role
                  Map<String, bool> defaultPermissions = _getDefaultPermissions(selectedRole);

                  // Create staff member in Firestore using UID as document ID
                  await FirebaseFirestore.instance.collection('users').doc(authUid).set({
                    'name': name,
                    'phone': phone,
                    'email': email,
                    'uid': authUid, // Store UID for reference
                    'storeId': storeId, // Link staff to store
                    'role': selectedRole,
                    'isActive': true,
                    'permissions': defaultPermissions,
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': widget.uid,
                  });

                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    Navigator.pop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Staff member "$name" added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    String errorMessage = 'Error creating account';

                    switch (e.code) {
                      case 'email-already-in-use':
                        errorMessage = 'This email is already registered in Firebase Authentication';
                        break;
                      case 'weak-password':
                        errorMessage = 'Password is too weak';
                        break;
                      case 'invalid-email':
                        errorMessage = 'Invalid email format';
                        break;
                      default:
                        errorMessage = 'Error: ${e.message}';
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
              ),
              child: const Text('Add Staff', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, bool> _getDefaultPermissions(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return {
          // Menu Items (7)
          'quotation': true,
          'billHistory': true,
          'creditNotes': true,
          'customerManagement': true,
          'expenses': true,
          'creditDetails': true,
          'staffManagement': true,

          // Report Items (14)
          'analytics': true,
          'daybook': true,
          'salesSummary': true,
          'salesReport': true,
          'itemSalesReport': true,
          'topCustomer': true,
          'stockReport': true,
          'lowStockProduct': true,
          'topProducts': true,
          'topCategory': true,
          'expensesReport': true,
          'taxReport': true,
          'hsnReport': true,
          'staffSalesReport': true,

          // Stock Items (2)
          'addProduct': true,
          'addCategory': true,
        };
      case 'manager':
        return {
          // Menu Items
          'quotation': true,
          'billHistory': true,
          'creditNotes': true,
          'customerManagement': true,
          'expenses': true,
          'creditDetails': true,
          'staffManagement': false,

          // Report Items
          'analytics': true,
          'daybook': true,
          'salesSummary': true,
          'salesReport': true,
          'itemSalesReport': true,
          'topCustomer': true,
          'stockReport': true,
          'lowStockProduct': true,
          'topProducts': true,
          'topCategory': true,
          'expensesReport': true,
          'taxReport': true,
          'hsnReport': true,
          'staffSalesReport': false,

          // Stock Items
          'addProduct': true,
          'addCategory': true,
        };
      default: // Staff
        return {
          // Menu Items
          'quotation': false,
          'billHistory': true,
          'creditNotes': false,
          'customerManagement': true,
          'expenses': false,
          'creditDetails': false,
          'staffManagement': false,

          // Report Items
          'analytics': false,
          'daybook': false,
          'salesSummary': false,
          'salesReport': false,
          'itemSalesReport': false,
          'topCustomer': false,
          'stockReport': false,
          'lowStockProduct': false,
          'topProducts': false,
          'topCategory': false,
          'expensesReport': false,
          'taxReport': false,
          'hsnReport': false,
          'staffSalesReport': false,

          // Stock Items
          'addProduct': false,
          'addCategory': false,
        };
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
                    helperText: 'Email is tied to Firebase Authentication',
                    helperMaxLines: 2,
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Name cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // Update Firestore document (staffId is now the UID)
                  await FirebaseFirestore.instance.collection('users').doc(staffId).update({
                    'name': name,
                    'role': selectedRole,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  // Also update Firebase Auth display name
                  try {
                    // Since staffId is the UID, we can directly update
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser != null && currentUser.uid == staffId) {
                      await currentUser.updateDisplayName(name);
                    }
                    // Note: To update other users' display names, you need Firebase Admin SDK
                  } catch (e) {
                    print('Could not update auth display name: $e');
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Staff member updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
              ),
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
      // Menu Items (7)
      'quotation': currentPermissions['quotation'] ?? false,
      'billHistory': currentPermissions['billHistory'] ?? false,
      'creditNotes': currentPermissions['creditNotes'] ?? false,
      'customerManagement': currentPermissions['customerManagement'] ?? false,
      'expenses': currentPermissions['expenses'] ?? false,
      'creditDetails': currentPermissions['creditDetails'] ?? false,
      'staffManagement': currentPermissions['staffManagement'] ?? false,

      // Report Items (14)
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

      // Stock Items (2)
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
                  await FirebaseFirestore.instance.collection('users').doc(staffId).update({
                    'permissions': permissions,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permissions updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
              ),
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF007AFF),
          ),
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
          );
        }).toList(),
      ],
    );
  }

  void _showStaffDetailsDialog(
    BuildContext context,
    String staffId,
    String name,
    String phone,
    String email,
    String role,
    bool isActive,
    Map<String, dynamic> permissions,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              const Text(
                'Active Permissions:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...permissions.entries
                  .where((e) => e.value == true)
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatPermissionName(e.key),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
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

  void _toggleStaffStatus(String staffId, bool newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(staffId).update({
        'isActive': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Staff member ${newStatus ? "activated" : "deactivated"} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, String staffId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff Member'),
        content: Text('Are you sure you want to delete "$name"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('users').doc(staffId).delete();

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Staff member deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

