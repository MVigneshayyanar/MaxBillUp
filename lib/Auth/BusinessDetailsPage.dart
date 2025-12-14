import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/utils/translation_helper.dart';

class BusinessDetailsPage extends StatefulWidget {
  final String uid;
  final String? email;
  final String? displayName;

  const BusinessDetailsPage({
    super.key,
    required this.uid,
    this.email,
    this.displayName,
  });

  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _businessPhoneCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController(); // Added GSTIN Controller
  final _businessLocationCtrl = TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name from Google account if available
    if (widget.displayName != null && widget.displayName!.isNotEmpty) {
      _nameCtrl.text = widget.displayName!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _businessNameCtrl.dispose();
    _businessPhoneCtrl.dispose();
    _gstinCtrl.dispose();
    _businessLocationCtrl.dispose();
    super.dispose();
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<int> _getNextStoreId() async {
    final firestore = FirebaseFirestore.instance;

    // Get the highest store ID from existing stores
    final querySnapshot = await firestore
        .collection('store')
        .orderBy('storeId', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return 100001; // First store ID
    }

    final lastStoreId = querySnapshot.docs.first.data()['storeId'] as int? ?? 100000;
    return lastStoreId + 1;
  }

  Future<void> _saveBusinessDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // Get next store ID
      final storeId = await _getNextStoreId();

      // Create store document
      final storeData = {
        'storeId': storeId,
        'ownerName': _nameCtrl.text.trim(),
        'ownerPhone': _phoneCtrl.text.trim(),
        'businessName': _businessNameCtrl.text.trim(),
        'businessPhone': _businessPhoneCtrl.text.trim(),
        'businessLocation': _businessLocationCtrl.text.trim(),
        'gstin': _gstinCtrl.text.trim(), // Save GSTIN (Optional)
        'ownerEmail': widget.email,
        'ownerUid': widget.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save store with storeId as document ID
      await firestore.collection('store').doc(storeId.toString()).set(storeData);

      // Create/update user document with uid as document ID
      final userData = {
        'uid': widget.uid,
        'email': widget.email,
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'storeId': storeId,
        'role': 'admin', // First user is Admin
        'isActive': true,
        'isEmailVerified': true,
        'businessLocation': _businessLocationCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore.collection('users').doc(widget.uid).set(userData);

      _showMsg('Business registered successfully!');

      // Navigate to main app
      if (mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.email),
          ),
        );
      }
    } catch (e) {
      _showMsg('Failed to save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Business Details',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Welcome message
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please provide your business details to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // Personal Details Section
                _sectionHeader('Personal Details'),
                const SizedBox(height: 16),

                _label('Your Name'),
                _buildTextField(
                  controller: _nameCtrl,
                  hint: 'Enter your full name',
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 20),

                _label('Your Phone Number'),
                _buildTextField(
                  controller: _phoneCtrl,
                  hint: 'Enter your phone number',
                  keyboardType: TextInputType.phone,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone is required';
                    if (v.trim().length != 10) return 'Enter valid 10-digit phone';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Business Details Section
                _sectionHeader('Business Details'),
                const SizedBox(height: 16),

                _label('Business Name'),
                _buildTextField(
                  controller: _businessNameCtrl,
                  hint: 'Enter your business name',
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Business name is required'
                      : null,
                ),
                const SizedBox(height: 20),

                _label('Business Phone Number'),
                _buildTextField(
                  controller: _businessPhoneCtrl,
                  hint: 'Enter business phone number',
                  keyboardType: TextInputType.phone,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Business phone is required';
                    if (v.trim().length != 10) return 'Enter valid 10-digit phone';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                _label('GSTIN (Optional)'),
                _buildTextField(
                  controller: _gstinCtrl,
                  hint: 'Enter GSTIN number',
                  validator: (v) => null, // Optional
                ),
                const SizedBox(height: 20),

                _label('Business Location'),
                _buildTextField(
                  controller: _businessLocationCtrl,
                  hint: 'Enter your business location',
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Business location is required'
                      : null,
                ),
                const SizedBox(height: 40),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveBusinessDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.6),
                    ),
                    child: _loading
                        ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Complete Registration',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Row(
    children: [
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    ],
  );

  Widget _label(String txt) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      txt,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
