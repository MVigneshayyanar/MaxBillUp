import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _auth = FirebaseAuth.instance;

  // false = Gmail tab active, true = Staff (email/password) tab active
  bool _isStaff = false;
  bool _hidePass = true;
  bool _loading = false;

  // OTP variables (kept for future use if needed)
  bool _otpSent = false;
  String _verifyId = '';
  int? _resendToken;
  final String _countryCode = '+91';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF00B8FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigate(String uid, String? identifier) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => NewSalePage(uid: uid, userEmail: identifier),
      ),
    );
  }

  // --- UPDATED GOOGLE LOGIN LOGIC ---
  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      // 1. Force account selection to ensure fresh login intent
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      final GoogleSignInAccount? gUser = await googleSignIn.signIn();

      if (gUser == null) {
        if (mounted) setState(() => _loading = false);
        return; // User cancelled the picker
      }

      // 2. Get credentials from Google
      final GoogleSignInAuthentication gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      // 3. Sign in to Firebase Auth (Creates auth record if new)
      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;

      if (user != null) {
        // 4. Check if Business Data exists in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!mounted) return;
        setState(() => _loading = false);

        if (userDoc.exists) {
          // Case A: Existing User -> Go to App
          _showMsg('Welcome back!');
          _navigate(user.uid, user.email);
        } else {
          // Case B: New User (or Incomplete Setup) -> Go to Business Details
          _showMsg('Please complete your business profile.');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BusinessDetailsPage(
                uid: user.uid,
                email: user.email,
                displayName: user.displayName, // Pass name to pre-fill
              ),
            ),
          );
        }
      } else {
        throw FirebaseAuthException(
            code: 'user-null',
            message: 'Sign in succeeded but user is null'
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _loading = false);
      _showMsg('Auth Error: ${e.message}');
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showMsg('Error: $e');
    }
  }

  Future<void> _emailLogin() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMsg('Please enter a valid email');
      return;
    }
    if (pass.length < 6) {
      _showMsg('Password must be at least 6 characters');
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      if (cred.user != null) {
        // Staff login usually implies existing setup, but you could add a doc check here too if needed
        _navigate(cred.user!.uid, cred.user!.email);
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed';
      if (e.code == 'user-not-found') msg = 'No account found.';
      if (e.code == 'wrong-password') msg = 'Incorrect password.';
      if (e.code == 'invalid-credential') msg = 'Invalid credentials.';
      _showMsg(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPass() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showMsg('Enter your email to reset password');
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showMsg('Password reset email sent');
    } on FirebaseAuthException catch (e) {
      _showMsg(e.message ?? 'Reset failed');
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
              // Show Google form when not staff, show staff email/password form when _isStaff is true
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
      const SizedBox(height: 16),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Image.asset(
          'assets/logo.png',
          width: 300,
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback if logo asset is missing
            return const Text("MAXBILLUP", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF00B8FF)));
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
        _otpSent = false;
        // Clear errors/loading state when switching tabs
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
              const Text('Continue with Google', style: TextStyle(fontSize: 16, color: Colors.black87)),
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

// Custom painter to draw a Google 'G' like logo (fallback if asset missing)
class GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final strokeWidth = size.width * 0.22;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const double startAngle = -3.14 / 4;
    final double sweep = 3.14 * 1.6;
    // red
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, startAngle, sweep * 0.23, false, paint);
    // yellow
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, startAngle + sweep * 0.23, sweep * 0.23, false, paint);
    // green
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, startAngle + sweep * 0.46, sweep * 0.23, false, paint);
    // blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, startAngle + sweep * 0.69, sweep * 0.31, false, paint);

    final innerPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - strokeWidth * 1.25, innerPaint);

    final tailPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.9
      ..strokeCap = StrokeCap.round;

    final tailStart = Offset(center.dx + radius * 0.05, center.dy + radius * 0.25);
    final tailEnd = Offset(center.dx + radius * 0.45, center.dy + radius * 0.05);
    canvas.drawLine(tailStart, tailEnd, tailPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}