import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/utils/language_provider.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/plan_provider.dart';

// Ensure these imports match your file structure
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/Auth/BusinessDetailsPage.dart';
import 'package:maxbillup/Admin/Home.dart';

// --- UI CONSTANTS ---
import 'package:maxbillup/Colors.dart';

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

  // --- Logic Helpers ---

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        backgroundColor: isError ? kErrorColor : kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _navigate(String uid, String? identifier) async {
    if (!mounted) return;
    final planProvider = Provider.of<PlanProvider>(context, listen: false);
    await planProvider.initialize();
    if (!mounted) return;

    if (identifier != null && identifier.toLowerCase() == 'maxmybillapp@gmail.com') {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (context) => HomePage(uid: uid, userEmail: identifier)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (context) => NewSalePage(uid: uid, userEmail: identifier)),
      );
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
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kBlack87)),
        content: Text(message, style: const TextStyle(color: kBlack54, height: 1.5, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('close').toUpperCase(), style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          if (onAction != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onAction();
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text(actionText.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // --- Auth Logic (Preserved) ---

  Future<void> _emailLogin() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMsg(context.tr('invalid_email'), isError: true);
      return;
    }
    if (pass.length < 6) {
      _showMsg(context.tr('password_too_short'), isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: pass);
      User? user = cred.user;
      if (user == null) throw Exception('Login failed');

      await user.reload();
      user = _auth.currentUser;
      final bool isAuthVerified = user?.emailVerified ?? false;

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
        final globalDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (globalDoc.exists) {
          userRef = globalDoc.reference;
          userData = globalDoc.data() as Map<String, dynamic>;
        } else {
          await _auth.signOut();
          setState(() => _loading = false);
          _showMsg(context.tr('login_failed'), isError: true);
          return;
        }
      }

      if (isAuthVerified) {
        Map<String, dynamic> updates = {'lastLogin': FieldValue.serverTimestamp()};
        if (!(userData['isEmailVerified'] ?? false)) {
          updates['isEmailVerified'] = true;
          updates['verifiedAt'] = FieldValue.serverTimestamp();
        }
        if (userData.containsKey('tempPassword')) updates['tempPassword'] = FieldValue.delete();
        await userRef.update(updates);
      } else {
        await userRef.update({'lastLogin': FieldValue.serverTimestamp()});
        await _auth.signOut();
        setState(() => _loading = false);
        _showDialog(
            title: '📧 VERIFY EMAIL',
            message: 'Please check your inbox and verify your email address to continue.',
            actionText: 'Resend Email',
            onAction: () async {
              await user?.sendEmailVerification();
              _showMsg('Verification email sent!');
            });
        return;
      }

      if (!(userData['isActive'] ?? false)) {
        await _auth.signOut();
        setState(() => _loading = false);
        _showDialog(
          title: '⏳ APPROVAL PENDING',
          message: 'Your account is waiting for Admin approval.',
        );
        return;
      }

      await _firestoreService.notifyStoreDataChanged();
      setState(() => _loading = false);
      _navigate(user.uid, user.email);
    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      _showMsg(e.message ?? 'Login failed', isError: true);
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
      final credential = GoogleAuthProvider.credential(accessToken: gAuth.accessToken, idToken: gAuth.idToken);
      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;

      if (user != null) {
        final userEmail = user.email?.toLowerCase().trim();
        if (userEmail == 'maxmybillapp@gmail.com') {
          if (mounted) setState(() => _loading = false);
          _navigate(user.uid, user.email);
          return;
        }
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) setState(() => _loading = false);
        if (userDoc.exists) {
          await _firestoreService.notifyStoreDataChanged();
          _navigate(user.uid, user.email);
        } else {
          Navigator.push(context, CupertinoPageRoute(builder: (context) => BusinessDetailsPage(uid: user.uid, email: user.email, displayName: user.displayName)));
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

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, _) {
        return Scaffold(
          backgroundColor: kWhite,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  //_buildLanguagePicker(langProvider),
                  const SizedBox(height: 40),
                  _buildHeader(context),
                  const SizedBox(height: 48),
                  _buildTabs(context),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isStaff ? _buildEmailForm(context) : _buildGoogleForm(context),
                  ),
                  const SizedBox(height: 32),
                  _buildPrimaryActionBtn(context),
                  const SizedBox(height: 56),
                  _buildTerms(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguagePicker(LanguageProvider langProvider) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: kGreyBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGrey200),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: langProvider.currentLanguageCode,
            icon: const Icon(Icons.language_rounded, color: kPrimaryColor, size: 18),
            style: const TextStyle(fontSize: 12, color: kBlack87, fontWeight: FontWeight.w800),
            onChanged: (newLang) { if (newLang != null) langProvider.changeLanguage(newLang); },
            items: langProvider.languages.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value['native']?.toUpperCase() ?? entry.value['name']?.toUpperCase() ?? entry.key),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Column(
    children: [
      Text(context.tr('welcome_to').toUpperCase(),
          style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
      const SizedBox(height: 12),
      SvgPicture.asset(
        'assets/max_my_bill_sq.svg',
        width: 300,
        height: 175,
        fit: BoxFit.contain,
      ),
    ],
  );

  Widget _buildTabs(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: kGreyBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kPrimaryColor, width: 1.5),
    ),
    child: Row(
      children: [
        _tabItem(context.tr('Sign In / Sign up').toUpperCase(), !_isStaff, true),
        _tabItem('${context.tr('staff')} ${context.tr('login')}'.toUpperCase(), _isStaff, false),
      ],
    ),
  );

  Widget _tabItem(String txt, bool active, bool isCustomer) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() { _isStaff = !isCustomer; _loading = false; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 44,
        decoration: BoxDecoration(
          color: active ? kPrimaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active ? [BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Center(
          child: Text(txt,
              style: TextStyle(
                  color: active ? kWhite : kBlack54,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5)),
        ),
      ),
    ),
  );

  Widget _buildEmailForm(BuildContext context) => Column(
    key: const ValueKey('email_form'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildTextField(
        _emailCtrl,
        context.tr('email').toUpperCase(),
        Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),
      _buildTextField(
        _passCtrl,
        context.tr('password').toUpperCase(),
        Icons.lock_outline_rounded,
        obscure: _hidePass,
        suffix: IconButton(
          icon: Icon(
            _hidePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: kPrimaryColor,
            size: 20,
          ),
          onPressed: () => setState(() => _hidePass = !_hidePass),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _loading ? null : _resetPass,
          child: Text(
            context.tr('forgot_password').toUpperCase(),
            style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
          ),
        ),
      ),
    ],
  );

  Widget _buildGoogleForm(BuildContext context) => Column(
    key: const ValueKey('google_form'),
    children: [
      const SizedBox(height: 8),
      Text(context.tr('SIGN IN WITH GOOGLE').toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: kBlack54, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: _loading ? null : _googleLogin,
          style: OutlinedButton.styleFrom(
            backgroundColor: kWhite,
            side: const BorderSide(color: kGrey200, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24, height: 24,
                child: Image.asset('assets/google.png', errorBuilder: (ctx, err, stack) => CustomPaint(size: const Size(22, 22), painter: GoogleGPainter())),
              ),
              const SizedBox(width: 14),
              const Text('GOOGLE ACCOUNT', style: TextStyle(fontSize: 14, color: kBlack87, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildTextField(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        bool obscure = false,
        Widget? suffix,
        TextInputType? keyboardType,
      }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15, color: kBlack87, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: hasText ? kPrimaryColor : kBlack54, size: 20),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
            floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
            filled: true,
            fillColor: kWhite,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: suffix,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrimaryActionBtn(BuildContext context) {
    String txt = _isStaff ? context.tr('login_staff').toUpperCase() : "CONTINUE WITH GOOGLE";
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _loading ? null : (_isStaff ? _emailLogin : _googleLogin),
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: kWhite))
            : Text(txt, style: const TextStyle(color: kWhite, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
      ),
    );
  }

  Widget _buildTerms(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: kBlack54, height: 1.6, fontWeight: FontWeight.w500),
        children: [
          TextSpan(text: "${context.tr('by_proceeding_agree')} "),
          const TextSpan(text: 'TERMS & CONDITIONS', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900)),
          const TextSpan(text: ', '),
          const TextSpan(text: 'PRIVACY POLICY', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900)),
          const TextSpan(text: ' & '),
          const TextSpan(text: 'REFUND POLICY', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900)),
        ],
      ),
    ),
  );
}

class GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.22;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;

    const double startAngle = -3.14 / 4;
    final double sweep = 3.14 * 1.6;

    paint.color = kGoogleRed;
    canvas.drawArc(rect, startAngle, sweep * 0.23, false, paint);
    paint.color = kOrange;
    canvas.drawArc(rect, startAngle + sweep * 0.23, sweep * 0.23, false, paint);
    paint.color = kGoogleGreen;
    canvas.drawArc(rect, startAngle + sweep * 0.46, sweep * 0.23, false, paint);
    paint.color = kPrimaryColor;
    canvas.drawArc(rect, startAngle + sweep * 0.69, sweep * 0.31, false, paint);

    final innerPaint = Paint()..color = kWhite..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - strokeWidth * 1.25, innerPaint);

    final tailPaint = Paint()..color = kPrimaryColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth * 0.9..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx + radius * 0.05, center.dy + radius * 0.25), Offset(center.dx + radius * 0.45, center.dy + radius * 0.05), tailPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}