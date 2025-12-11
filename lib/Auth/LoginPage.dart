import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:maxbillup/utils/firestore_service.dart';

// Ensure these imports match your file structure
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
        duration: const Duration(seconds: 4),
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

  // --- GOOGLE LOGIN LOGIC (Business Owner) ---
  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      final GoogleSignInAccount? gUser = await googleSignIn.signIn();

      if (gUser == null) {
        if (mounted) setState(() => _loading = false);
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
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!mounted) return;
        setState(() => _loading = false);

        if (userDoc.exists) {
          _showMsg('Welcome back!');
          _navigate(user.uid, user.email);
        } else {
          _showMsg('Please complete your business profile.');
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
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _loading = false);
      _showMsg('Auth Error: ${e.message}', isError: true);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showMsg('Error: $e', isError: true);
    }
  }

  // --- ENHANCED STAFF LOGIN LOGIC ---
  Future<void> _emailLogin() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    // Validation
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
      // 1. Sign in with email/password
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      User? user = cred.user;

      if (user == null) {
        throw Exception('Login failed - no user returned');
      }

      // 2. CRITICAL: Reload user to get fresh emailVerified status
      await user.reload();
      user = _auth.currentUser;

      if (user == null) {
        throw Exception('Session lost after reload');
      }

      print('📧 User: ${user.email}, Email Verified: ${user.emailVerified}');

      // 3. Check email verification from Firebase Auth
      if (!user.emailVerified) {
        await _auth.signOut();
        setState(() => _loading = false);

        _showDialog(
          title: '📧 Email Not Verified',
          message: 'Please verify your email address first.\n\nCheck your inbox (and spam folder) for the verification link.',
          actionText: 'Resend Email',
          onAction: () async {
            try {
              await user?.sendEmailVerification();
              _showMsg('Verification email sent! Check your inbox.');
            } catch (e) {
              _showMsg('Failed to send email: $e', isError: true);
            }
          },
        );
        return;
      }

      // 4. Find user document in store-scoped collection
      DocumentSnapshot? userDoc;

      try {
        // Try to get from store-scoped collection
        final storeCollection = await _firestoreService.getStoreCollection('users');
        final querySnapshot = await storeCollection
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          userDoc = querySnapshot.docs.first;
        }
      } catch (e) {
        print('Error finding user in store collection: $e');
      }

      // Fallback: Try root users collection
      if (userDoc == null || !userDoc.exists) {
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
      }

      if (!userDoc.exists) {
        await _auth.signOut();
        setState(() => _loading = false);
        _showMsg('Account not found. Please contact your administrator.', isError: true);
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final bool isActive = userData['isActive'] ?? false;
      final bool dbEmailVerified = userData['isEmailVerified'] ?? false;

      // 5. Update Firestore isEmailVerified if it's false but Auth says true
      if (!dbEmailVerified && user.emailVerified) {
        print('✅ Syncing email verification to Firestore');

        try {
          await _firestoreService.updateDocument('users', user.uid, {
            'isEmailVerified': true,
            'verifiedAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          print('Error updating Firestore: $e');
          // Try direct update as fallback
          await userDoc.reference.update({
            'isEmailVerified': true,
            'verifiedAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Just update last login
        try {
          await _firestoreService.updateDocument('users', user.uid, {
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          await userDoc.reference.update({
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }
      }

      // 6. Check if admin has approved (isActive)
      if (!isActive) {
        await _auth.signOut();
        setState(() => _loading = false);

        _showDialog(
          title: '⏳ Pending Approval',
          message: 'Your email is verified!\n\nYour account is waiting for administrator approval. Please contact your admin to activate your access.',
          actionText: 'OK',
        );
        return;
      }

      // 7. SUCCESS - All checks passed
      setState(() => _loading = false);
      _showMsg('✅ Login successful! Welcome back.');
      _navigate(user.uid, user.email);

    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      String msg = 'Login failed';

      switch (e.code) {
        case 'user-not-found':
          msg = 'No account found with this email.';
          break;
        case 'wrong-password':
          msg = 'Incorrect password. Please try again.';
          break;
        case 'invalid-credential':
          msg = 'Invalid email or password.';
          break;
        case 'user-disabled':
          msg = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          msg = 'Too many failed attempts. Please try again later.';
          break;
        default:
          msg = e.message ?? msg;
      }

      _showMsg(msg, isError: true);
    } catch (e) {
      setState(() => _loading = false);
      _showMsg('Error: $e', isError: true);
      print('❌ Login error: $e');
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B8FF),
              ),
              child: Text(actionText, style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Future<void> _resetPass() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showMsg('Enter your email to reset password', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showMsg('✅ Password reset email sent! Check your inbox.');
    } on FirebaseAuthException catch (e) {
      _showMsg(e.message ?? 'Reset failed', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
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
              const SizedBox(height: 80),
              _buildTerms(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(
    children: [
      const Text('Welcome to',
          style: TextStyle(fontSize: 28, color: Colors.black87)),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Image.asset(
          'assets/logo.png',
          width: 300,
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Text("MAXBILLUP",
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00B8FF)));
          },
        ),
      ),
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
            left: txt.contains('Gmail')
                ? const Radius.circular(8)
                : Radius.zero,
            right: txt.contains('Staff')
                ? const Radius.circular(8)
                : Radius.zero,
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
      _label('Email'),
      _input(_emailCtrl, 'Enter your staff email',
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 24),
      _label('Password'),
      _input(_passCtrl, 'Enter your password',
          obscure: _hidePass,
          suffix: IconButton(
            icon: Icon(
                _hidePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey[600]),
            onPressed: () => setState(() => _hidePass = !_hidePass),
          )),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _loading ? null : _resetPass,
          child: const Text('Forgot Password?',
              style: TextStyle(
                  color: Color(0xFF00B8FF),
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    ],
  );

  Widget _buildGoogleForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(height: 8),
      const Text('Sign in using your Google (Gmail) account',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black87)),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: _loading ? null : _googleLogin,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: ClipOval(
                  child: Image.asset(
                    'assets/google.png',
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => CustomPaint(
                      size: const Size(30, 30),
                      painter: GoogleGPainter(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text('Continue with Google',
                  style: TextStyle(fontSize: 16, color: Colors.black87)),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _label(String txt) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(txt,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87)),
  );

  Widget _input(TextEditingController ctrl, String hint,
      {bool obscure = false,
        Widget? suffix,
        bool enabled = true,
        TextInputType? keyboardType,
        TextAlign textAlign = TextAlign.start,
        TextStyle? style,
        List<TextInputFormatter>? formatters}) =>
      Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          enabled: enabled,
          keyboardType: keyboardType,
          textAlign: textAlign,
          style: style ?? const TextStyle(fontSize: 16, color: Colors.black87),
          inputFormatters: formatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: suffix,
          ),
        ),
      );

  Widget _buildButton() {
    String txt = _isStaff ? 'Login (Staff)' : 'Sign in with Google';
    VoidCallback? action = _isStaff ? _emailLogin : _googleLogin;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _loading ? null : action,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00B8FF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          disabledBackgroundColor:
          const Color(0xFF00B8FF).withValues(alpha: 0.6),
        ),
        child: _loading
            ? const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white))
            : Text(txt,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildTerms() => RichText(
    textAlign: TextAlign.center,
    text: const TextSpan(
      style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
      children: [
        TextSpan(text: 'By Proceeding, you agree to our '),
        TextSpan(
            text: 'Terms and Conditions',
            style: TextStyle(
                color: Color(0xFF00B8FF), fontWeight: FontWeight.w600)),
        TextSpan(text: ', '),
        TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
                color: Color(0xFF00B8FF), fontWeight: FontWeight.w600)),
        TextSpan(text: ' & '),
        TextSpan(
            text: 'Refund and Cancellation Policy',
            style: TextStyle(
                color: Color(0xFF00B8FF), fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.22;
    final rect =
    Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const double startAngle = -3.14 / 4;
    final double sweep = 3.14 * 1.6;

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, startAngle, sweep * 0.23, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, startAngle + sweep * 0.23, sweep * 0.23, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, startAngle + sweep * 0.46, sweep * 0.23, false, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, startAngle + sweep * 0.69, sweep * 0.31, false, paint);

    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - strokeWidth * 1.25, innerPaint);

    final tailPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.9
      ..strokeCap = StrokeCap.round;

    final tailStart =
    Offset(center.dx + radius * 0.05, center.dy + radius * 0.25);
    final tailEnd = Offset(center.dx + radius * 0.45, center.dy + radius * 0.05);
    canvas.drawLine(tailStart, tailEnd, tailPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
