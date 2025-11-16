import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Auth/LoginEmail.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
    print('Please run: flutter clean && flutter pub get && flutter run');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BillUP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00B8FF)),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const LoginEmailPage(),
    );
  }
}
