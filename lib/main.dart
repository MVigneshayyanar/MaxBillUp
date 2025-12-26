import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'Auth/SplashPage.dart';
import 'firebase_options.dart';
import 'package:maxbillup/utils/theme_notifier.dart';
import 'package:maxbillup/utils/language_provider.dart';
import 'package:maxbillup/utils/plan_provider.dart';
import 'package:maxbillup/models/sale.dart';
import 'package:maxbillup/services/sale_sync_service.dart';
import 'package:maxbillup/services/local_stock_service.dart';
import 'package:maxbillup/services/direct_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive for offline storage
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  Hive.registerAdapter(SaleAdapter());

  // Initialize SaleSyncService for offline sales syncing
  final saleSyncService = SaleSyncService();
  await saleSyncService.init();

  // Initialize LocalStockService for offline stock management
  final localStockService = LocalStockService();
  await localStockService.init();

  // Initialize LanguageProvider and load saved preference
  final languageProvider = LanguageProvider();
  await languageProvider.loadLanguagePreference();

  // Initialize PlanProvider for real-time plan updates
  final planProvider = PlanProvider();

  // Initialize DirectNotificationService in background (non-blocking)
  final notificationService = DirectNotificationService();
  notificationService.initialize(); // Run in background, don't await

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider<PlanProvider>.value(value: planProvider),
        Provider<SaleSyncService>.value(value: saleSyncService),
        ChangeNotifierProvider<LocalStockService>.value(value: localStockService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MAXmybill',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F7CF6)),
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F7CF6), brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.black,
      ),
      themeMode: themeNotifier.themeMode,
      home: const SplashPage(), // Use custom splash page directly
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

