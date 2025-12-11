import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import 'Auth/SplashPage.dart';
import 'Auth/LoginPage.dart';
import 'firebase_options.dart';
import 'Sales/NewSale.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MAXmybill',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00B8FF)),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashGate(),
      builder: (context, child) {
        // Lock screen orientation to portrait
        return OrientationBuilder(
          builder: (context, orientation) {
            if (orientation != Orientation.portrait) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
              });
            }
            return child!;
          },
        );
      },
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _requestBluetoothPermissions();
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // User is logged in
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (_) => NewSalePage(
              uid: user.uid,
              userEmail: user.email,
            ),
          ),
        );
      } else {
        // User is NOT logged in
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const LoginPage()),
        );
      }
    });
  }

  /// Request Bluetooth and location permissions for printer connectivity
  /// Auto-enables Bluetooth if user allows permission
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
          print('Bluetooth enabled successfully');
        } catch (e) {
          print('Error enabling Bluetooth: $e');
        }
      }
    } catch (e) {
      print('Error requesting Bluetooth permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashPage();
  }
}
