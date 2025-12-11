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
  // --- Controllers & Services (From Code 2) ---
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestoreService = FirestoreService();

  // --- State Variables ---
  bool _isStaff = false; // false = Gmail tab, true = Staff tab
  bool _hidePass = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // --- Helpers (Logic from Code 2, Styling from Code 1) ---

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        // Logic from Code 2 (Red/Blue), Behavior from Code 1
        backgroundColor: isError ? const Color(0xFFFF3B30) : const Color(0xFF00B8FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigate(String uid, String? identifier) {
    if (!mounted) return;
    // Functionality from Code 2 (CupertinoPageRoute)
    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(
        builder: (context) => NewSalePage(uid: uid, userEmail: identifier),
      ),
    );
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

  // --- AUTH LOGIC (Strictly from Code 2) ---

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
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: pass);
      User? user = cred.user;

      if (user == null) throw Exception('Login failed');

      // 2. FORCE RELOAD to get the latest emailVerified status
      await user.reload();
      user = _auth.currentUser;

      final bool isAuthVerified = user?.emailVerified ?? false;

      // 3. Find the User Document in Firestore
      // Check store-scoped collection first
      QuerySnapshot storeUserQuery =
      await (await _firestoreService.getStoreCollection('users'))
          .where('uid', isEqualTo: user!.uid)
          .limit(1)
          .get();

      DocumentReference? userRef;
      Map<String, dynamic> userData;

      if (storeUserQuery.docs.isNotEmpty) {
        userRef = storeUserQuery.docs.first.reference;
        userData = storeUserQuery.docs.first.data() as Map<String, dynamic>;
      } else {
        // Fallback to global users collection
        final globalDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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

      // 4. SYNC STATUS
      bool dbVerified = userData['isEmailVerified'] ?? false;

      if (isAuthVerified) {
        Map<String, dynamic> updates = {
          'lastLogin': FieldValue.serverTimestamp(),
        };

        if (!dbVerified) {
          updates['isEmailVerified'] = true;
          updates['verifiedAt'] = FieldValue.serverTimestamp();
        }

        if (userData.containsKey('tempPassword')) {
          updates['tempPassword'] = FieldValue.delete();
        }

        await userRef.update(updates);

        userData['isEmailVerified'] = true;
        userData['isActive'] = userData['isActive'] ?? false;
      } else {
        userRef
            .update({'lastLogin': FieldValue.serverTimestamp()}).catchError((_) {});
      }

      // 5. Verification Gate
      if (!isAuthVerified) {
        await _auth.signOut();
        setState(() => _loading = false);
        _showDialog(
            title: '📧 Verify Email',
            message:
            'Please check your inbox and verify your email address to continue.',
            actionText: 'Resend Email',
            onAction: () async {
              await user?.sendEmailVerification();
              _showMsg('Verification email sent!');
            });
        return;
      }

      // 6. Approval Gate (isActive)
      bool isActive = userData['isActive'] ?? false;

      if (!isActive) {
        await _auth.signOut();
        setState(() => _loading = false);
        _showDialog(
          title: '⏳ Approval Pending',
          message:
          'Your email is verified! \n\nHowever, your account is waiting for Admin approval.\n\nPlease ask your store admin to approve your account.',
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

  Future<void> _resetPass() async {
    if (_emailCtrl.text.isEmpty) {
      _showMsg('Enter email to reset password', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.sendPasswordResetEmail(email: _emailCtrl.text.trim());
      _showMsg('Reset link sent!');
    } catch (e) {
      _showMsg('Error sending reset link', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- UI BUILD (Strictly from Code 1) ---

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
              // Conditional Form Rendering
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
        // Clear errors on tab switch if needed
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

// --- Custom Painter for Google Logo (From Code 1) ---
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
    paint.color = const Color(0xFF2196F3);
    canvas.drawArc(rect, startAngle + sweep * 0.69, sweep * 0.31, false, paint);

    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - strokeWidth * 1.25, innerPaint);

    final tailPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.9
      ..strokeCap = StrokeCap.round;

    final tailStart =
    Offset(center.dx + radius * 0.05, center.dy + radius * 0.25);
    final tailEnd =
    Offset(center.dx + radius * 0.45, center.dy + radius * 0.05);
    canvas.drawLine(tailStart, tailEnd, tailPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}