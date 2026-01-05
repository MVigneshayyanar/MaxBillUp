import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:maxbillup/Colors.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'LoginPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/Admin/Home.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/services/in_app_update_service.dart';

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

    // Check for in-app updates (Android only)
    InAppUpdateService.checkForUpdate();

    // Removed automatic permission requests - will be requested lazily when needed
    // _requestBluetoothPermissions(); // Only request when user tries to use Bluetooth printer

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
  /// This is now a public static method that can be called when needed
  static Future<bool> requestBluetoothPermissions() async {
    try {
      // Request Bluetooth permissions (Android 12+)
      final bluetoothStatus = await Permission.bluetooth.request();
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();

      // Request location permission (required for Bluetooth scanning on Android)
      final locationStatus = await Permission.location.request();

      // If all permissions granted, enable Bluetooth
      if (bluetoothStatus.isGranted && scanStatus.isGranted && connectStatus.isGranted && locationStatus.isGranted) {
        try {
          await FlutterBluePlus.turnOn();
          debugPrint('✅ Bluetooth enabled successfully');
          return true;
        } catch (e) {
          debugPrint('⚠️ Error enabling Bluetooth: $e');
          return true; // Still return true if permissions granted
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error requesting Bluetooth permissions: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size to determine device type
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final diagonal = sqrt(screenWidth * screenWidth + screenHeight * screenHeight);

    // Determine if device is tablet/iPad (diagonal > 7 inches assuming ~160 dpi)
    // Typically tablets have diagonal > 1100 pixels
    final isTablet = diagonal > 1100 || screenWidth > 600;

    // Choose appropriate splash image with correct file extension
    final splashImage = isTablet ? 'assets/MAX_my_bill_tab.png' : 'assets/MAX_my_bill_mobile.png';

    return Scaffold(
      backgroundColor: Color(0xff4456E0),
      body: SizedBox.expand(
        child: Image.asset(
          splashImage,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
