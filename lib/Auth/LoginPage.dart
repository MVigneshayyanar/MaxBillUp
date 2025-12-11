import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:maxbillup/utils/firestore_service.dart';

import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/Auth/BusinessDetailsPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestoreService = FirestoreService();

  bool _isStaff = false;
  bool _hidePass = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFFF3B30) : const Color(0xFF00B8FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigate(String uid, String? identifier) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(
        builder: (context) => NewSalePage(uid: uid, userEmail: identifier),
      ),
    );
  }

  Future<void> _emailLogin() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMsg('Please enter a valid email', isError: true);
      return;
    }
    if (pass.length < 6) {
      _showMsg('Password must be at least 6 characters', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      // 1. Authenticate with Firebase Auth
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: pass);
      User? user = cred.user;

      if (user == null) throw Exception('Login failed');

      // 2. FORCE RELOAD to get the latest emailVerified status from Firebase
      await user.reload();
      user = _auth.currentUser;

      final bool isAuthVerified = user?.emailVerified ?? false;

      // 3. Find the User Document in Firestore
      // We check the store-scoped collection first
      QuerySnapshot storeUserQuery = await (await _firestoreService.getStoreCollection('users'))
          .where('uid', isEqualTo: user!.uid)
          .limit(1)
          .get();

      DocumentReference? userRef;
      Map<String, dynamic> userData;

      if (storeUserQuery.docs.isNotEmpty) {
        userRef = storeUserQuery.docs.first.reference;
        userData = storeUserQuery.docs.first.data() as Map<String, dynamic>;
      } else {
        // Fallback to global users collection if not found in store scope
        final globalDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (globalDoc.exists) {
          userRef = globalDoc.reference;
          userData = globalDoc.data() as Map<String, dynamic>;
        } else {
          await _auth.signOut();
          setState(() => _loading = false);
          _showMsg('User record not found in database.', isError: true);
          return;
        }
      }

      // 4. SYNC STATUS: Update Firestore if Auth says verified but DB doesn't
      // This acts as a fallback if the Admin hasn't auto-checked yet.
      bool dbVerified = userData['isEmailVerified'] ?? false;

      if (isAuthVerified) {
        // If verified, we clean up the tempPassword for security and ensure DB is consistent
        Map<String, dynamic> updates = {
          'lastLogin': FieldValue.serverTimestamp(),
        };

        if (!dbVerified) {
          updates['isEmailVerified'] = true;
          updates['verifiedAt'] = FieldValue.serverTimestamp();
        }

        // Always try to delete tempPassword on successful login for security
        if (userData.containsKey('tempPassword')) {
          updates['tempPassword'] = FieldValue.delete();
        }

        await userRef.update(updates);

        // Update local map for the checks below
        userData['isEmailVerified'] = true;
        userData['isActive'] = userData['isActive'] ?? false; // Refresh logic
      } else {
        // Just update last login attempt
        userRef.update({'lastLogin': FieldValue.serverTimestamp()}).catchError((_) {});
      }

      // 5. Verification Gate
      if (!isAuthVerified) {
        await _auth.signOut();
        setState(() => _loading = false);
        _showDialog(
            title: '📧 Verify Email',
            message: 'Please check your inbox and verify your email address to continue.',
            actionText: 'Resend Email',
            onAction: () async {
              await user?.sendEmailVerification();
              _showMsg('Verification email sent!');
            }
        );
        return;
      }

      // 6. Approval Gate (isActive)
      // We re-fetch or use the map to check if the Admin has approved this user
      bool isActive = userData['isActive'] ?? false;

      if (!isActive) {
        await _auth.signOut();
        setState(() => _loading = false);
        _showDialog(
          title: '⏳ Approval Pending',
          message: 'Your email is verified! \n\nHowever, your account is waiting for Admin approval.\n\nPlease ask your store admin to approve your account.',
        );
        return;
      }

      // 7. Success
      setState(() => _loading = false);
      _navigate(user.uid, user.email);

    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      String msg = e.message ?? 'Login failed';
      if (e.code == 'user-not-found') msg = 'Account does not exist.';
      if (e.code == 'wrong-password') msg = 'Incorrect password.';
      _showMsg(msg, isError: true);
    } catch (e) {
      setState(() => _loading = false);
      _showMsg('Error: $e', isError: true);
    }
  }

  // --- GOOGLE LOGIN (For Business Owners) ---
  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? gUser = await googleSignIn.signIn();

      if (gUser == null) {
        setState(() => _loading = false);
        return;
      }

      final GoogleSignInAuthentication gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (mounted) setState(() => _loading = false);

        if (userDoc.exists) {
          _navigate(user.uid, user.email);
        } else {
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute(
              builder: (context) => BusinessDetailsPage(
                uid: user.uid,
                email: user.email,
                displayName: user.displayName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showMsg('Google Sign In Error: $e', isError: true);
    }
  }

  void _showDialog({
    required String title,
    required String message,
    String actionText = 'OK',
    VoidCallback? onAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (onAction != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onAction();
              },
              child: Text(actionText),
            ),
        ],
      ),
    );
  }

  Future<void> _resetPass() async {
    if (_emailCtrl.text.isEmpty) {
      _showMsg('Enter email to reset password', isError: true);
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: _emailCtrl.text.trim());
      _showMsg('Reset link sent!');
    } catch (e) {
      _showMsg('Error sending reset link', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildHeader(),
              const SizedBox(height: 60),
              _buildTabs(),
              const SizedBox(height: 40),
              _isStaff ? _buildEmailForm() : _buildGoogleForm(),
              const SizedBox(height: 40),
              _buildButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(
    children: [
      const Text('Welcome to', style: TextStyle(fontSize: 28, color: Colors.black87)),
      const SizedBox(height: 12),
      const Text("MAXBILLUP", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF00B8FF))),
    ],
  );

  Widget _buildTabs() => Row(
    children: [
      _tab('Login (Gmail)', !_isStaff),
      _tab('Staff Login', _isStaff),
    ],
  );

  Widget _tab(String txt, bool active) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() {
        _isStaff = !_isStaff;
        _loading = false;
      }),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00B8FF) : Colors.white,
          border: Border.all(color: const Color(0xFF00B8FF), width: 1.5),
          borderRadius: BorderRadius.horizontal(
            left: txt.contains('Gmail') ? const Radius.circular(8) : Radius.zero,
            right: txt.contains('Staff') ? const Radius.circular(8) : Radius.zero,
          ),
        ),
        child: Center(
          child: Text(txt,
              style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF00B8FF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  );

  Widget _buildEmailForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          hintText: 'Enter staff email',
        ),
      ),
      const SizedBox(height: 24),
      const Text('Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      TextField(
        controller: _passCtrl,
        obscureText: _hidePass,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          hintText: 'Enter password',
          suffixIcon: IconButton(
            icon: Icon(_hidePass ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _hidePass = !_hidePass),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _resetPass,
          child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFF00B8FF))),
        ),
      ),
    ],
  );

  Widget _buildGoogleForm() => Column(
    children: [
      const SizedBox(height: 20),
      const Text('Sign in using your Google account', style: TextStyle(fontSize: 16)),
      const SizedBox(height: 20),
    ],
  );

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _loading ? null : (_isStaff ? _emailLogin : _googleLogin),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00B8FF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(_isStaff ? 'Login (Staff)' : 'Sign in with Google',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}