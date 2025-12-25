import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'LoginPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maxbillup/Sales/NewSale.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    debugPrint('Splash screen started at: \\${DateTime.now()}');
    // Navigate after 3 seconds
    Timer(const Duration(seconds: 40), () {
      debugPrint('Splash screen ended at: \\${DateTime.now()}');
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => NewSalePage(
              uid: user.uid,
              userEmail: user.email,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => const LoginPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2F7CF6),
      body: SizedBox.expand(
        child: Image.asset(
          'assets/Splash_Screen.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
