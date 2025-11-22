import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  bool _isPhone = false;
  bool _hidePass = true;
  bool _loading = false;
  bool _otpSent = false;
  String _verifyId = '';
  int? _resendToken;
  String _countryCode = '+91';

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
        _navigate(cred.user!.uid, cred.user!.email);
      }
    } on FirebaseAuthException catch (e) {
      final errors = {
        'user-not-found': 'No account found. Please sign up first.',
        'wrong-password': 'Incorrect password.',
        'invalid-credential': 'Invalid email or password.',
        'too-many-requests': 'Too many attempts. Try again later.',
      };
      _showMsg(errors[e.code] ?? 'Login failed: ${e.message}');
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
      _showMsg(e.code == 'user-not-found'
          ? 'No account found with this email'
          : 'Failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendOTP() async {
    if (_phoneCtrl.text.trim().length != 10) {
      _showMsg('Enter valid 10-digit phone number');
      return;
    }

    setState(() => _loading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: _countryCode + _phoneCtrl.text.trim(),
      verificationCompleted: (cred) => _signInWithCred(cred),
      verificationFailed: (e) {
        setState(() => _loading = false);
        _showMsg('Verification failed: ${e.message}');
      },
      codeSent: (id, token) {
        setState(() {
          _verifyId = id;
          _resendToken = token;
          _otpSent = true;
          _loading = false;
        });
        _showMsg('OTP sent');
      },
      codeAutoRetrievalTimeout: (id) => _verifyId = id,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
    );
  }

  Future<void> _verifyOTP() async {
    if (_otpCtrl.text.trim().length != 6) {
      _showMsg('Enter valid 6-digit OTP');
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verifyId,
        smsCode: _otpCtrl.text.trim(),
      );
      await _signInWithCred(cred);
    } catch (e) {
      setState(() => _loading = false);
      _showMsg('Invalid OTP');
    }
  }

  Future<void> _signInWithCred(PhoneAuthCredential cred) async {
    try {
      final user = await _auth.signInWithCredential(cred);
      if (user.user != null) {
        _navigate(user.user!.uid, user.user!.phoneNumber);
      }
    } catch (e) {
      _showMsg('Sign in failed');
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
              _isPhone ? _buildPhoneForm() : _buildEmailForm(),
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
      // Logo image added below the title
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.only(top: 0),
        child: Image.asset(
          'assets/logo.png',
          width: 300,
          height: 50,
          fit: BoxFit.contain,
        ),
      ),
    ],
  );

  Widget _buildTabs() => Row(
    children: [
      _tab('Login with Email', !_isPhone),
      _tab('Login with Phone', _isPhone),
    ],
  );

  Widget _tab(String txt, bool active) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() {
        _isPhone = !_isPhone;
        _otpSent = false;
      }),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00B8FF) : Colors.white,
          border: Border.all(color: const Color(0xFF00B8FF), width: 1.5),
          borderRadius: BorderRadius.horizontal(
            left: txt.contains('Email')
                ? const Radius.circular(8)
                : Radius.zero,
            right: txt.contains('Phone')
                ? const Radius.circular(8)
                : Radius.zero,
          ),
        ),
        child: Center(
          child: Text(txt,
              style: TextStyle(
                  color:
                  active ? Colors.white : const Color(0xFF00B8FF),
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
      _input(_emailCtrl, 'Enter your login email',
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

  Widget _buildPhoneForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label('Phone Number'),
      Row(
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(_countryCode,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _input(_phoneCtrl, '',
                enabled: !_otpSent,
                keyboardType: TextInputType.phone,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ]),
          ),
        ],
      ),
      if (_otpSent) ...[
        const SizedBox(height: 24),
        _label('Enter OTP'),
        _input(_otpCtrl, '000000',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 8),
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ]),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Didn't receive OTP?",
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            TextButton(
              onPressed: _loading ? null : _sendOTP,
              child: const Text('Resend OTP',
                  style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF00B8FF),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
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
    String txt = _isPhone ? (_otpSent ? 'Verify OTP' : 'Send OTP') : 'Login';
    VoidCallback? action =
    _isPhone ? (_otpSent ? _verifyOTP : _sendOTP) : _emailLogin;

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
        TextSpan(
            text:
            '. SMS would be send to your Registered mobile number for verification purposes.'),
      ],
    ),
  );
}

class SmileyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00B8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final path = Path()
      ..moveTo(5, 0)
      ..quadraticBezierTo(size.width / 2, size.height, size.width - 5, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}