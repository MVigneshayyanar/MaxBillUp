import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/NewSale.dart'; // Import NewSalePage
import 'package:maxbillup/Auth/LoginNumber.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginEmailPage extends StatefulWidget {
  const LoginEmailPage({super.key});

  @override
  State<LoginEmailPage> createState() => _LoginEmailPageState();
}

class _LoginEmailPageState extends State<LoginEmailPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isPhoneLogin = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Sign in with email and password
  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Validation
    if (email.isEmpty) {
      _showSnackBar('Please enter your email');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showSnackBar('Please enter a valid email address');
      return;
    }
    if (password.isEmpty) {
      _showSnackBar('Please enter your password');
      return;
    }
    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Sign in with Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if sign in was successful
      if (userCredential.user != null) {
        final uid = userCredential.user!.uid;
        final email = userCredential.user!.email;
        print('Login successful: $email (UID: $uid)');

        if (!mounted) return;

        setState(() => _isLoading = false);

        // Navigate to main app on success with UID
        Future.microtask(() {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => NewSalePage(uid: uid, userEmail: email),
              ),
            );
          }
        });
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Login failed. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      setState(() => _isLoading = false);

      // Handle specific error cases
      String errorMessage;
      switch (e.code) {
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection and try again.';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this email. Please sign up first.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address format.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid credentials. Please check your email and password.';
          break;
        default:
          errorMessage = 'Login failed: ${e.message}';
      }
      _showSnackBar(errorMessage);
    } catch (e) {
      print('General exception during login: $e');
      setState(() => _isLoading = false);
      _showSnackBar('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnackBar('Please enter your email to reset password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.sendPasswordResetEmail(email: email);
      setState(() => _isLoading = false);
      _showSnackBar('Password reset email sent. Please check your inbox.');
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        default:
          errorMessage = 'Failed to send reset email: ${e.message}';
      }
      _showSnackBar(errorMessage);
    }
  }

  // Show snackbar message
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF00B8FF),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                // Welcome text and logo
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'Welcome to',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'bill',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            TextSpan(
                              text: 'UP',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00B8FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Smiley face under UP
                      Container(
                        margin: const EdgeInsets.only(left: 60, top: 4),
                        child: CustomPaint(
                          size: const Size(50, 25),
                          painter: SmileyPainter(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                // Tab buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        'Login with Email',
                        !_isPhoneLogin,
                            () {
                          setState(() {
                            _isPhoneLogin = false;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        'Login with Phone',
                        _isPhoneLogin,
                            () {
                          // Navigate to LoginNumber page
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginNumberPage()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Email input
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your login email',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Password input
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xFF00B8FF),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B8FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: const Color(0xFF00B8FF).withValues(alpha: 0.6),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 80),
                // Terms and conditions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: 'By Proceeding, you agree to our '),
                        TextSpan(
                          text: 'Terms and Conditions',
                          style: TextStyle(
                            color: Color(0xFF00B8FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ', '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: Color(0xFF00B8FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ' & '),
                        TextSpan(
                          text: 'Refund and Cancellation Policy',
                          style: TextStyle(
                            color: Color(0xFF00B8FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text:
                          '. SMS would be send to your Registered mobile number for verification purposes.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00B8FF) : Colors.white,
          border: Border.all(
            color: const Color(0xFF00B8FF),
            width: 1.5,
          ),
          borderRadius: BorderRadius.horizontal(
            left: text.contains('Email') ? const Radius.circular(8) : Radius.zero,
            right: text.contains('Phone') ? const Radius.circular(8) : Radius.zero,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF00B8FF),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for the smiley face
class SmileyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00B8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final path = Path();
    path.moveTo(5, 0);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width - 5,
      0,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
