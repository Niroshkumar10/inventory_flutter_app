import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/ai_provider.dart';
import 'core/navigation/auth_notifier.dart';
import 'package:go_router/go_router.dart';
import 'core/navigation/app_router.dart';
import 'package:inventory_app/core/utils/app_logger.dart';
import 'notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    appLogger.i('✅ Firebase initialized');
  } catch (e) {
    appLogger.e('❌ Firebase init failed: $e');
  }

  // runApp immediately — do NOT await NotificationService here.
  // FCM token fetch and permission request can block indefinitely on some
  // devices, causing a black screen before Flutter renders anything.
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _authNotifier = AuthNotifier();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authNotifier.init();
    _router = createRouter(_authNotifier);

    // Init notifications in the background after the UI is up.
    if (!kIsWeb) {
      NotificationService().init().catchError((e, st) {
        debugPrint('[NOTIF] ❌ Unhandled error in NotificationService.init(): $e\n$st');
      });
    }
  }

  @override
  void dispose() {
    _authNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AIProvider()),
        ChangeNotifierProvider.value(value: _authNotifier),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'Kadai',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
