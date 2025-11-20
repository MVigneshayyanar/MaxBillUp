// Import necessary packages
import 'package:flutter/material.dart';
import 'package:maxbillup/components/common_bottom_nav.dart'; // Assuming this is your bottom nav bar
// TODO: Import your authentication service (e.g., FirebaseAuth)
// import 'package:firebase_auth/firebase_auth.dart';
// TODO: Import your database service (e.g., FirebaseFirestore)
// import 'package:cloud_firestore/cloud_firestore.dart';

// TODO: Import your other settings pages
// import 'package:maxbillup/settings/business_details_page.dart';
// import 'package:maxbillup/auth/login_page.dart';


class SettingsPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const SettingsPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Variables to hold user data
  String _userName = "Sam"; // Default/loading value
  String _userEmail = "sam07@gmail.com"; // Default/loading value
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _userEmail = widget.userEmail ?? "loading...";
    // Fetch user data when the page loads
    _fetchUserData();
  }

  /// Fetches user data from your backend (e.g., Firestore)
  Future<void> _fetchUserData() async {
    // setState(() => _isLoading = true); // Show a loading indicator if you want

    /*
    // TODO: Implement your backend logic here
    try {
      // Example using Firestore:
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _userName = doc.data()?['displayName'] ?? 'No Name';
          _userEmail = doc.data()?['email'] ?? widget.userEmail ?? 'No Email';
        });
      }
    } catch (e) {
      // Handle error
      print("Error fetching user data: $e");
      setState(() {
        _userName = "Error";
        _userEmail = "Could not load data";
      });
    } finally {
      // setState(() => _isLoading = false);
    }
    */

    // For now, we'll just use the mock data after a short delay
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _userName = "Sam";
      _userEmail = widget.userEmail ?? "sam07@gmail.com";
      _isLoading = false;
    });
  }

  /// Handles the logout action
  Future<void> _logout() async {
    // TODO: Implement your authentication logic
    /*
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate to the login screen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()), // Replace with your LoginPage
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("Error logging out: $e");
      // Show a snackbar or dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to log out. Please try again.")),
      );
    }
    */

    // Placeholder action
    print("User logged out");
    // Example navigation (replace with your actual login page)
    // Navigator.of(context).pushAndRemoveUntil(
    //   MaterialPageRoute(builder: (context) => YourLoginPage()),
    //   (route) => false
    // );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light gray background
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Title
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // User Info Card
                _buildUserInfoCard(_userName, _userEmail),
                const SizedBox(height: 32),

                // App Settings Section
                _buildSection(
                  title: 'App Settings',
                  tiles: [
                    _buildListTile(
                      icon: Icons.store_outlined,
                      title: 'Business Details', // Corrected spelling
                      onTap: () {
                        // TODO: Navigate to Business Details Page
                        // Navigator.push(context, MaterialPageRoute(builder: (context) => BusinessDetailsPage()));
                        print("Tapped Business Details");
                      },
                    ),
                    _buildListTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'Receipt',
                      onTap: () { /* TODO: Navigate */ },
                    ),
                    _buildListTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'TAX / WAT',
                      onTap: () { /* TODO: Navigate */ },
                    ),
                    _buildListTile(
                      icon: Icons.print_outlined,
                      title: 'Printer Setup',
                      onTap: () { /* TODO: Navigate */ },
                    ),
                    _buildListTile(
                      icon: Icons.settings_suggest_outlined,
                      title: 'Feature Settings',
                      onTap: () { /* TODO: Navigate */ },
                    ),
                    _buildListTile(
                      icon: Icons.language_outlined,
                      title: 'Languages',
                      onTap: () { /* TODO: Navigate */ },
                    ),
                    _buildListTile(
                      icon: Icons.color_lens_outlined,
                      title: 'Theme',
                      onTap: () { /* TODO: Navigate */ },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Support & Service Section
                _buildSection(
                  title: 'Support & Service',
                  tiles: [
                    _buildListTile(
                      icon: Icons.help_outline,
                      title: 'Help',
                      onTap: () { /* TODO: Navigate */ },
                    ),
                    _buildListTile(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Market Place',
                      onTap: () { /* TODO: Navigate */ },
                    ),
                    _buildListTile(
                      icon: Icons.share_outlined,
                      title: 'Refer A Friend',
                      onTap: () { /* TODO: Navigate */ },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Version Number
                const Center(
                  child: Text(
                    'v .5167',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _logout, // Connect the logout function
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'logout',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16), // Space for bottom nav
              ],
            ),
          ),
        ),
      ),
      // Use your existing CommonBottomNav
      bottomNavigationBar: CommonBottomNav(
        uid: widget.uid,
        userEmail: widget.userEmail,
        currentIndex: 4, // 4 is the index for Settings
        screenWidth: screenWidth,
      ),
    );
  }

  /// Helper widget to build the user info card
  Widget _buildUserInfoCard(String name, String email) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            // TODO: Replace with user's profile image
            backgroundImage: NetworkImage('https://via.placeholder.com/150'), // Placeholder
            backgroundColor: Colors.grey,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade100.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Administrator',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget to build a section with a title and list tiles
  Widget _buildSection({required String title, required List<Widget> tiles}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          // Use ListView.separated for clean dividers
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(), // Disable scrolling
            shrinkWrap: true,
            itemCount: tiles.length,
            itemBuilder: (context, index) => tiles[index],
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF5F5F5),
              indent: 16,
              endIndent: 16,
            ),
          ),
        ),
      ],
    );
  }

  /// Helper widget to build a consistent list tile
  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }
}