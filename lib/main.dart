import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/user_profile.dart';
import 'providers/request_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/passenger/passenger_home.dart';
import 'screens/staff/staff_dashboard.dart';
import 'services/notification_service.dart';
import 'widgets/app_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RailSahayakBootstrap());
}

class RailSahayakBootstrap extends StatefulWidget {
  const RailSahayakBootstrap({super.key});

  @override
  State<RailSahayakBootstrap> createState() => _RailSahayakBootstrapState();
}

class _RailSahayakBootstrapState extends State<RailSahayakBootstrap> {
  bool _servicesReady = false;
  Object? _startupError;
  late DateTime _startupStartedAt;

  static const _minimumSplashDuration = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    _startupStartedAt = DateTime.now();
    unawaited(_initializeServices());
  }

  Future<void> _initializeServices() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await GoogleSignIn.instance.initialize();

      try {
        await NotificationService.instance.initialize();
      } catch (e) {
        debugPrint('Notification initialization failed: $e');
      }

      final elapsed = DateTime.now().difference(_startupStartedAt);
      final remaining = _minimumSplashDuration - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }

      if (!mounted) return;
      setState(() {
        _servicesReady = true;
        _startupError = null;
      });
    } catch (e, stackTrace) {
      debugPrint('Startup initialization error: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;
      setState(() {
        _startupError = e;
        _servicesReady = false;
      });
    }
  }

  Future<void> _retryStartup() async {
    if (!mounted) return;
    setState(() {
      _startupError = null;
      _servicesReady = false;
      _startupStartedAt = DateTime.now();
    });
    await _initializeServices();
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'RailSahayak could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Please try again.', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _retryStartup,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_servicesReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AppSplash(),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => RequestProvider(),
      child: const MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Timer? _routeTimer;
  bool _keepSplash = true;

  static const _minimumPostServiceSplash = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    _routeTimer = Timer(_minimumPostServiceSplash, () {
      if (mounted) setState(() => _keepSplash = false);
    });
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();

    return MaterialApp(
      title: 'RailSahayak Accessibility Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          primary: Colors.orange.shade800,
          secondary: Colors.indigo.shade800,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          bodyLarge: TextStyle(fontSize: 16, height: 1.4),
          bodyMedium: TextStyle(fontSize: 14, height: 1.3),
        ),
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      home: (_keepSplash || !provider.isSessionInitialized)
          ? const AppSplash()
          : _getHomeRoute(
              provider.currentUser,
              provider.needsProfileCompletion,
            ),
    );
  }

  Widget _getHomeRoute(UserProfile? user, bool needsProfileCompletion) {
    if (user == null) return const LoginScreen();
    if (needsProfileCompletion) return ProfileCompletionScreen();
    if (user.role == UserRole.staff) return const StaffDashboard();
    return const PassengerHome();
  }
}
