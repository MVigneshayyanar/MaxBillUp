import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==========================================
// 1. MAIN MENU PAGE (Updated UI)
// ==========================================
class MenuPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const MenuPage({
    super.key,
    required this.uid,
    this.userEmail
  });

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String _businessName = "Loading...";
  String _email = "";
  String _role = "admin";

  @override
  void initState() {
    super.initState();
    _email = widget.userEmail ?? "user@email.com";
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();

      if (doc.exists && mounted) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _businessName = data['businessName'] ?? data['name'] ?? 'My Business';
          _email = data['email'] ?? _email;
          _role = data['role'] ?? 'Staff';
        });
      }
    } catch (e) {
      debugPrint("Error loading menu: $e");
    }
  }

  void _showRegistrationSheet(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final _formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool isSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Text('Register New User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email (optional)'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const Text('or', style: TextStyle(color: Colors.grey)),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone (optional)'),
                      keyboardType: TextInputType.phone,
                    ),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                    ),
                    const SizedBox(height: 16),
                    if (isSuccess)
                      Column(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 48),
                          const SizedBox(height: 8),
                          const Text('Account created successfully!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    if (!isSuccess)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    final email = emailController.text.trim();
                                    final phone = phoneController.text.trim();
                                    final password = passwordController.text.trim();
                                    if (email.isEmpty && phone.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter email or phone')));
                                      return;
                                    }
                                    setState(() => isLoading = true);
                                    try {
                                      if (email.isNotEmpty) {
                                        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
                                        setState(() => isSuccess = true);
                                        await Future.delayed(const Duration(seconds: 1));
                                        Navigator.pop(context);
                                      } else if (phone.isNotEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone registration requires verification. Please use email for now.')));
                                      }
                                    } on FirebaseAuthException catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Registration failed')));
                                    } finally {
                                      setState(() => isLoading = false);
                                    }
                                  },
                            child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Register'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';
    // Define the exact blue color from the screenshot
    const Color brandBlue = Color(0xFF0D47A1);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ================= HEADER =================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
            color: brandBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _businessName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAdmin)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.person_add, color: Colors.white),
                            tooltip: 'Register New Account',
                            onPressed: () => _showRegistrationSheet(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  _email,
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  _role,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ),

          // ================= MENU ITEMS =================
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('Register New User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () => _showRegistrationSheet(context),
                    ),
                  ),
                _buildMenuItem(Icons.shopping_bag_outlined, "New Sale", () {}),
                _buildMenuItem(Icons.request_quote_outlined, "Quotation", () {}),
                _buildMenuItem(Icons.receipt_long_outlined, "Bill History", () {}),
                _buildMenuItem(Icons.description_outlined, "Credit Notes", () {}),

                // Highlighted Item style (if needed)
                _buildMenuItem(Icons.inventory_2_outlined, "Inventory / Stock", () {}, isHighlighted: false),

                _buildMenuItem(Icons.people_alt_outlined, "Customer Management", () {}),

                // Expenses Dropdown
                ExpansionTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.black87),
                  title: const Text("Expenses", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500)),
                  childrenPadding: const EdgeInsets.only(left: 72), // Indent sub-items
                  iconColor: Colors.black87,
                  collapsedIconColor: Colors.black87,
                  children: [
                    _buildSubMenuItem("Stock Purchase", () {}),
                    _buildSubMenuItem("Expenses", () {}),
                    _buildSubMenuItem("Other Expenses", () {}),
                    _buildSubMenuItem("Expense Category", () {}),
                  ],
                ),

                // Staff Management (Conditional)
                if (isAdmin)
                  _buildMenuItem(
                      Icons.badge_outlined,
                      "Staff Management",
                          () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => StaffManagementList(adminUid: widget.uid)));
                      }
                  ),

                _buildMenuItem(Icons.assignment_outlined, "Credit Details", () {}),
                _buildMenuItem(Icons.menu_book_outlined, "DayBook", () {}),
                _buildMenuItem(Icons.pie_chart_outline, "Report", () {}),

                const Divider(height: 30, thickness: 1), // Separator before footer items

                _buildMenuItem(Icons.settings_outlined, "Settings", () {}),
                _buildMenuItem(Icons.help_outline, "Help", () {}),
              ],
            ),
          ),

          // ================= SUBSCRIPTION BANNER =================
          Container(
            color: const Color(0xFF1565C0), // Slightly lighter blue for footer
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: const Text("billeez", style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 10)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SUBSCRIPTION", style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1)),
                      Text("DETAILS", style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1)),
                    ],
                  ),
                ),
                const Icon(Icons.emoji_events, color: Colors.amber, size: 28), // Crown icon
              ],
            ),
          )
        ],
      ),
      bottomNavigationBar: CommonBottomNav(
        uid: widget.uid,
        userEmail: widget.userEmail,
        currentIndex: 0,
        screenWidth: MediaQuery.of(context).size.width,
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String text, VoidCallback onTap, {bool isHighlighted = false}) {
    return ListTile(
      leading: Icon(icon, color: isHighlighted ? const Color(0xFF0D47A1) : Colors.black87),
      title: Text(
          text,
          style: TextStyle(
              fontSize: 16,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
              color: isHighlighted ? const Color(0xFF0D47A1) : Colors.black87
          )
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      visualDensity: const VisualDensity(vertical: -2), // Compact look like screenshot
      onTap: onTap,
    );
  }

  Widget _buildSubMenuItem(String text, VoidCallback onTap) {
    return ListTile(
      title: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black54)),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -4),
      contentPadding: EdgeInsets.zero,
    );
  }
}

// ==========================================
// 2. STAFF MANAGEMENT LIST PAGE (Existing Logic)
// ==========================================
class StaffManagementList extends StatelessWidget {
  final String adminUid;
  const StaffManagementList({super.key, required this.adminUid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Staff Management', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AddStaffPage(adminUid: adminUid)));
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add New Staff"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D47A1),
                  side: const BorderSide(color: Color(0xFF0D47A1)),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                return ListView.separated(
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    String name = data['name'] ?? 'Unknown';
                    String email = data['email'] ?? '';
                    String role = data['role'] ?? 'Staff';
                    bool isActive = (data['status'] ?? '') == 'Active';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey.shade100,
                        child: Text(name.isNotEmpty ? name.substring(0, 2).toUpperCase() : "NA", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text("User Role : $role", style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
                              const Text("|", style: TextStyle(color: Colors.grey)),
                              const SizedBox(width: 8),
                              const Text("Status : ", style: TextStyle(fontSize: 12)),
                              Text(isActive ? "Active" : "Inactive", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.green : Colors.red)),
                              if(isActive) Container(margin: const EdgeInsets.only(left: 4), width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle))
                            ],
                          )
                        ],
                      ),
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
}

// ==========================================
// 3. ADD STAFF / PERMISSIONS PAGE (Existing Logic)
// ==========================================
class AddStaffPage extends StatefulWidget {
  final String adminUid;
  const AddStaffPage({super.key, required this.adminUid});

  @override
  State<AddStaffPage> createState() => _AddStaffPageState();
}

class _AddStaffPageState extends State<AddStaffPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedRole = "Administrator";
  final List<String> _roles = ["Administrator", "Cashier", "Sales"];

  Map<String, Map<String, dynamic>> permissions = {
    "Bill History": {
      "enabled": true,
      "desc": "This role enables user to view bill history, create return bills etc.",
      "sub": {"View Bill History": true, "Block Others Bill": true, "Return Bill": true, "Cancel bill / Edit bill": true}
    },
    "Inventory Management": {
      "enabled": true,
      "desc": "This role enables user to view inventory, create and edit inventory etc.",
      "sub": {"View Inventory": true, "Edit Inventory / Manage Stock": true, "Delete Inventory": true}
    },
    "Customer Management": {
      "enabled": true,
      "desc": "View customer details, create, edit and delete customer.",
      "sub": {"View Customer details": true, "Edit Customer details": true, "Delete Customer details": true}
    },
    "Quotation Management": {
      "enabled": true,
      "desc": "This role grants users to manage Quotations.",
      "sub": {"Create Quotation": true, "View Quotation": true}
    },
  };

  Future<void> _saveStaff() async {
    if(!_formKey.currentState!.validate()) return;
    try {
      await FirebaseFirestore.instance.collection('users').add({
        'name': _nameController.text,
        'email': _emailController.text,
        'role': _selectedRole,
        'status': 'Active',
        'parentAdmin': widget.adminUid,
        'createdAt': FieldValue.serverTimestamp(),
        'permissions': permissions,
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Staff Added Successfully")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Add New Staff', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField("Name", _nameController),
              const SizedBox(height: 12),
              _buildTextField("Login Mail id", _emailController, isEmail: true),
              const SizedBox(height: 12),
              _buildTextField("Password", _passwordController, isPassword: true),

              const SizedBox(height: 20),
              const Text("Select Staff Role", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedRole,
                    items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                ),
              ),

              const SizedBox(height: 25),
              const Text("PERMISSIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),

              ...permissions.keys.map((key) => _buildPermissionGroup(key)).toList(),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveStaff,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text("Update", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isEmail = false, bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        validator: (val) => val!.isEmpty ? "Required" : null,
      ),
    );
  }

  Widget _buildPermissionGroup(String title) {
    Map<String, dynamic> group = permissions[title]!;
    bool isEnabled = group['enabled'];
    Map<String, dynamic> subPermissions = group['sub'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      child: Column(
        children: [
          SwitchListTile(
            activeColor: Colors.green,
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(group['desc'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
            value: isEnabled,
            onChanged: (val) => setState(() => permissions[title]!['enabled'] = val),
          ),
          if (isEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Column(
                children: subPermissions.keys.map((subKey) {
                  return CheckboxListTile(
                    title: Text(subKey, style: const TextStyle(fontWeight: FontWeight.w500)),
                    value: subPermissions[subKey],
                    activeColor: const Color(0xFF0D47A1),
                    controlAffinity: ListTileControlAffinity.trailing,
                    onChanged: (val) => setState(() => permissions[title]!['sub'][subKey] = val),
                  );
                }).toList(),
              ),
            ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

