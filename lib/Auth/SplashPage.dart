import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'LoginPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/Admin/Home.dart';
import 'package:maxbillup/utils/plan_provider.dart';

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
    debugPrint('Splash screen started at: ${DateTime.now()}');

    // Start background tasks immediately
    _requestBluetoothPermissions();

    // Navigate after 2 seconds
    Timer(const Duration(seconds: 5), () {
      debugPrint('Splash screen ended at: ${DateTime.now()}');
      if (!mounted) return;
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Initialize PlanProvider in background (non-blocking)
      final planProvider = Provider.of<PlanProvider>(context, listen: false);
      planProvider.initialize(); // Don't await - let it run in background

      if (!mounted) return;

      // Check if the logged-in user is admin
      final userEmail = user.email?.toLowerCase() ?? '';
      if (userEmail == 'maxmybillapp@gmail.com') {
        // Navigate to Admin Home page
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (_) => HomePage(
              uid: user.uid,
              userEmail: user.email,
            ),
          ),
        );
      } else {
        // Navigate to NewSalePage for regular users
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (_) => NewSalePage(
              uid: user.uid,
              userEmail: user.email,
            ),
          ),
        );
      }
    } else {
      // User is NOT logged in
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  /// Request Bluetooth and location permissions for printer connectivity
  Future<void> _requestBluetoothPermissions() async {
    try {
      // Request Bluetooth permissions (Android 12+)
      final bluetoothStatus = await Permission.bluetooth.request();
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();

      // Request location permission (required for Bluetooth scanning on Android)
      await Permission.location.request();

      // If all permissions granted, enable Bluetooth
      if (bluetoothStatus.isGranted && scanStatus.isGranted && connectStatus.isGranted) {
        try {
          await FlutterBluePlus.turnOn();
          debugPrint('Bluetooth enabled successfully');
        } catch (e) {
          debugPrint('Error enabling Bluetooth: $e');
        }
      }
    } catch (e) {
      debugPrint('Error requesting Bluetooth permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2F7CF6),
      body: SizedBox.expand(
        child: Image.asset(
          'assets/Splash_Screen.png',
          fit: BoxFit.contain, // Changed from contain to cover for fullscreen
        ),
      ),
    );
  }
}
