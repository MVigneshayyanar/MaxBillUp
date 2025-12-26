import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        content: Text(msg),
        backgroundColor: isError ? kErrorColor : kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('close'), style: const TextStyle(color: Colors.grey)),
          ),
          if (onAction != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onAction();
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              child: Text(actionText),
            ),
        ],
      ),
    );
  }

  // --- Auth Logic ---

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
            title: '📧 Verify Email',
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
          title: '⏳ Approval Pending',
          message: 'Your account is waiting for Admin approval.',
        );
        return;
      }

      await _firestoreService.refreshCacheOnLogin();
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
          await _firestoreService.refreshCacheOnLogin();
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
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: kGrey100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButton<String>(
                        value: langProvider.currentLanguageCode,
                        icon: const Icon(Icons.language, color: kPrimaryColor, size: 18),
                        underline: const SizedBox(),
                        style: const TextStyle(fontSize: 14, color: kBlack87, fontWeight: FontWeight.bold),
                        onChanged: (newLang) {
                          if (newLang != null) langProvider.changeLanguage(newLang);
                        },
                        items: langProvider.languages.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value['native'] ?? entry.value['name'] ?? entry.key),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildHeader(context),
                  const SizedBox(height: 50),
                  _buildTabs(context),
                  const SizedBox(height: 40),
                  _isStaff ? _buildEmailForm(context) : _buildGoogleForm(context),
                  const SizedBox(height: 40),
                  _buildButton(context),
                  const SizedBox(height: 50),
                  _buildTerms(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) => Column(
    children: [
      TranslatedText('welcome_to', style: const TextStyle(fontSize: 24, color: kBlack54, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Image.asset(
        'assets/logo.png',
        width: 250,
        height: 60,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Text("MAXBILLUP",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: 1.2));
        },
      ),
    ],
  );

  Widget _buildTabs(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: kGreyBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        _tab(context.tr('Sign In / Sign up'), !_isStaff, true),
        _tab(context.tr('staff') + ' ' + context.tr('login'), _isStaff, false),
      ],
    ),
  );

  Widget _tab(String txt, bool active, bool isLeft) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() {
        _isStaff = isLeft ? false : true;
        _loading = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: active ? kPrimaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(txt,
              style: TextStyle(
                  color: active ? kWhite : kBlack54,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    ),
  );

  Widget _buildEmailForm(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(context.tr('email')),
      _input(_emailCtrl, context.tr('enter_email'), keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 20),
      _label(context.tr('password')),
      _input(_passCtrl, context.tr('enter_password'),
          obscure: _hidePass,
          suffix: IconButton(
            icon: Icon(_hidePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20),
            onPressed: () => setState(() => _hidePass = !_hidePass),
          )),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _loading ? null : _resetPass,
          child: TranslatedText('forgot_password', style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
        ),
      ),
    ],
  );

  Widget _buildGoogleForm(BuildContext context) => Column(
    children: [
      const SizedBox(height: 10),
      TranslatedText('Sign In / Sign up with Google', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: kBlack54)),
      const SizedBox(height: 30),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: _loading ? null : _googleLogin,
          style: OutlinedButton.styleFrom(
            backgroundColor: kWhite,
            side: BorderSide(color: kGrey300, width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Image.asset(
                  'assets/google.png',
                  errorBuilder: (ctx, err, stack) => CustomPaint(size: const Size(24, 24), painter: GoogleGPainter()),
                ),
              ),
              const SizedBox(width: 12),
              const Text('Google', style: TextStyle(fontSize: 16, color: kBlack87, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _label(String txt) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(txt, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kBlack87)),
  );

  Widget _input(TextEditingController ctrl, String hint, {bool obscure = false, Widget? suffix, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16, color: kBlack87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kGrey400, fontSize: 16),
        filled: true,
        fillColor: const Color(0xFFFAFAFA), // Lighter grey for input fill
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    String txt = _isStaff ? context.tr('login_staff') : "Google Login";
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _loading ? null : (_isStaff ? _emailLogin : _googleLogin),
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
            : Text(txt, style: const TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTerms(BuildContext context) => RichText(
    textAlign: TextAlign.center,
    text: TextSpan(
      style: const TextStyle(fontSize: 12, color: kBlack54, height: 1.6),
      children: [
        TextSpan(text: "${context.tr('by_proceeding_agree')} "),
        const TextSpan(text: 'Terms & Conditions', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
        const TextSpan(text: ', '),
        const TextSpan(text: 'Privacy Policy', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
        const TextSpan(text: ' & '),
        const TextSpan(text: 'Refund Policy', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
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
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;

    const double startAngle = -3.14 / 4;
    final double sweep = 3.14 * 1.6;

    paint.color = kGoogleRed;
    canvas.drawArc(rect, startAngle, sweep * 0.23, false, paint);
    paint.color = kGoogleYellow;
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
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}