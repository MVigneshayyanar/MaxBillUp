import 'dart:async'; // Required for StreamSubscription
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==========================================
// 1. MAIN MENU PAGE
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
  // Data variables
  String _businessName = "Loading...";
  String _email = "";
  String _role = "staff";

  // Subscription for real-time, fast updates
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // Colors
  final Color _headerBlue = const Color(0xFF007AFF);
  final Color _iconColor = const Color(0xFF424242);
  final Color _textColor = const Color(0xFF212121);

  @override
  void initState() {
    super.initState();
    _email = widget.userEmail ?? "maestromindssdg@gmail.com";
    _startFastUserDataListener();
  }

  // Optimized Fetching: Uses Stream for instant Cache load + Server background refresh
  void _startFastUserDataListener() {
    try {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots() // <--- FASTEST METHOD: Emits cache immediately, then server
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          setState(() {
            _businessName = data['businessName'] ?? data['name'] ?? 'Karadi Crackers';
            // Only update email from DB if it exists, otherwise keep passed value
            if (data.containsKey('email')) {
              _email = data['email'];
            }
            _role = data['role'] ?? 'Staff';
          });
        }
      }, onError: (e) {
        debugPrint("Error listening to user data: $e");
      });
    } catch (e) {
      debugPrint("Error initializing stream: $e");
    }
  }

  @override
  void dispose() {
    // strict cleanup to prevent memory leaks
    _userSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'administrator';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ================= HEADER =================
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 25,
                left: 20,
                right: 20
            ),
            color: _headerBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _businessName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _email,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // ================= MENU ITEMS =================
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _buildMenuItem(Icons.assignment_outlined, "Quotation", () {}),
                _buildMenuItem(Icons.receipt_long_outlined, "Bill History", () {}),
                _buildMenuItem(Icons.description_outlined, "Credit Notes", () {}),
                _buildMenuItem(Icons.group_outlined, "Customer Management", () {}),

                // Expenses Dropdown
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Icon(Icons.account_balance_wallet_outlined, color: _iconColor),
                    title: Text(
                        "Expenses",
                        style: TextStyle(fontSize: 16, color: _textColor, fontWeight: FontWeight.w500)
                    ),
                    iconColor: _iconColor,
                    collapsedIconColor: _iconColor,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                    childrenPadding: const EdgeInsets.only(left: 72),
                    children: [
                      _buildSubMenuItem("Stock Purchase", () {}),
                      _buildSubMenuItem("Expenses", () {}),
                      _buildSubMenuItem("Other Expenses", () {}),
                      _buildSubMenuItem("Expense Category", () {}),
                    ],
                  ),
                ),

                _buildMenuItem(Icons.request_quote_outlined, "Credit Details", () {}),

                _buildMenuItem(Icons.menu_book_outlined, "DayBook", () {}),

                if (isAdmin)
                  _buildMenuItem(Icons.badge_outlined, "Staff Management", () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => StaffManagementList(adminUid: widget.uid)));
                  }),
              ],
            ),
          ),
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

  Widget _buildMenuItem(IconData icon, String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: _iconColor),
        title: Text(
            text,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _textColor
            )
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSubMenuItem(String text, VoidCallback onTap) {
    return ListTile(
      title: Text(text, style: TextStyle(fontSize: 15, color: _textColor.withOpacity(0.8))),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: EdgeInsets.zero,
    );
  }
}

// ==========================================
// 2. STAFF MANAGEMENT LIST PAGE
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
        backgroundColor: const Color(0xFF007AFF),
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
                  foregroundColor: const Color(0xFF007AFF),
                  side: const BorderSide(color: Color(0xFF007AFF)),
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
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
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
// 3. ADD STAFF / PERMISSIONS PAGE
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
        backgroundColor: const Color(0xFF007AFF),
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
                    activeColor: const Color(0xFF007AFF),
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