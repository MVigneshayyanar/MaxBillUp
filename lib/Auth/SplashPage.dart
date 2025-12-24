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
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    // Start fade-in animation
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _opacity = 1.0;
      });
    });
    // Navigate after 3 seconds
    Timer(const Duration(seconds: 3), () {
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
      body: SafeArea(
        child: Center(
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(seconds: 3),
            curve: Curves.easeInOut,
            child: Image.asset(
              'assets/max_my_bill_sq.png',
              fit: BoxFit.contain,
              width: 300,
              height: 300,
            ),
          ),
        ),
      ),
    );
  }
}
