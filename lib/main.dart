import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/user_profile.dart';
import 'providers/request_provider.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/passenger/passenger_home.dart';
import 'screens/staff/staff_dashboard.dart';
import 'widgets/app_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start the Flutter UI immediately. Firebase/Google/notifications are
  // initialized in the background by StartupController so the animated
  // splash can render instead of leaving a blank/native launch screen.
  runApp(const RailSahayakBootstrap());
}

class RailSahayakBootstrap extends StatefulWidget {
  const RailSahayakBootstrap({super.key});

  @override
  State<RailSahayakBootstrap> createState() => _RailSahayakBootstrapState();
}

class _RailSahayakBootstrapState extends State<RailSahayakBootstrap> {
  bool _initialized = false;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await GoogleSignIn.instance.initialize();

      // Notifications should never block the app from opening.
      try {
        await NotificationService.instance.initialize();
      } catch (e) {
        debugPrint('Notification startup error: $e');
      }

      if (!mounted) return;
      setState(() {
        _initialized = true;
        _startupError = null;
      });
    } catch (e, stackTrace) {
      debugPrint('Startup initialization error: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;
      setState(() {
        _initialized = false;
        _startupError = e;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _startupError = null;
      _initialized = false;
    });
    await _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 56,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'RailSahayak could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _retry,
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

    if (!_initialized) {
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();

    return MaterialApp(
      title: 'RailSahayak Accessibility Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange.shade800,
          primary: Colors.orange.shade800,
          secondary: Colors.indigo.shade800,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
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
      home: provider.isSessionInitialized
          ? _getHomeRoute(
              provider.currentUser,
              provider.needsProfileCompletion,
            )
          : const AppSplash(),
    );
  }

  Widget _getHomeRoute(
    UserProfile? user,
    bool needsProfileCompletion,
  ) {
    if (user == null) return const LoginScreen();

    if (needsProfileCompletion) {
      return const ProfileCompletionScreen();
    }

    if (user.role == UserRole.staff) {
      return const StaffDashboard();
    }

    return const PassengerHome();
  }
}

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isSaving = false;
  bool _otpSent = false;
  bool _isVerifyingOtp = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<RequestProvider>().currentUser;
    if (user != null) {
      _usernameController.text = user.username;
      _phoneController.text = user.phone;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    if (_isSaving || _isVerifyingOtp) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave profile setup?'),
        content: const Text(
          'Your Google account will be signed out. You can sign in again later and continue setting up your RailSahayak profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    await context.read<RequestProvider>().logout();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final provider = context.read<RequestProvider>();

    final success = await provider.sendPhoneOtp(
      _phoneController.text,
      resend: _otpSent,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _otpSent = true;
        _otpController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent to your phone number.'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (provider.phoneVerificationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.phoneVerificationError!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the 6-digit OTP.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isVerifyingOtp = true);

    final provider = context.read<RequestProvider>();
    final success = await provider.verifyPhoneOtp(otp);

    if (!mounted) return;
    setState(() => _isVerifyingOtp = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number verified successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (provider.phoneVerificationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.phoneVerificationError!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<RequestProvider>();
    final user = provider.currentUser;

    if (user == null) return;

    if (!provider.phoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your phone number with the OTP first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final username = _usernameController.text.trim().toLowerCase();
      final phone = _phoneController.text
          .trim()
          .replaceAll(RegExp(r'[\s-]'), '');

      final success = await provider.completeProfile(
        username: username,
        phone: phone,
      );

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.phoneVerificationError ??
                  'Could not save your profile. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Profile completion error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your profile. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final user = provider.currentUser;
    final primaryColor = user?.role == UserRole.staff
        ? Colors.indigo.shade800
        : Colors.orange.shade800;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Complete Your Profile',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            TextButton.icon(
              onPressed: (_isSaving || _isVerifyingOtp) ? null : _logout,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                'Sign out',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: primaryColor.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.person_outline,
                            size: 48,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Almost there!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'We need a few more details before you can use RailSahayak.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (user != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.06),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.25),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Google Account',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _usernameController,
                          enabled: !_isSaving,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            hintText: 'Choose a username',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: primaryColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            final username = value?.trim() ?? '';
                            if (username.isEmpty) {
                              return 'Please enter a username';
                            }
                            if (username.length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9_]+$')
                                .hasMatch(username)) {
                              return 'Use only letters, numbers and _';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          enabled: !_isSaving &&
                              !_isVerifyingOtp &&
                              !provider.phoneVerified,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'Enter your 10-digit phone number',
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                              color: primaryColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            final phone = (value ?? '')
                                .replaceAll(RegExp(r'[\s-]'), '');
                            if (phone.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
                              return 'Enter a valid 10-digit phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        if (provider.phoneVerified)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.08),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.35),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified, color: Colors.green),
                                SizedBox(width: 10),
                                Text(
                                  'Phone number verified',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed:
                                  provider.phoneVerificationInProgress ||
                                          _isSaving ||
                                          _isVerifyingOtp
                                      ? null
                                      : _sendOtp,
                              icon: provider.phoneVerificationInProgress
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      Icons.sms_outlined,
                                      color: primaryColor,
                                    ),
                              label: Text(
                                _otpSent ? 'Resend OTP' : 'Send OTP',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (_otpSent && !provider.phoneVerified) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _otpController,
                            enabled: !_isVerifyingOtp && !_isSaving,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Enter OTP',
                              hintText: '6-digit code',
                              counterText: '',
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: primaryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isVerifyingOtp || _isSaving
                                  ? null
                                  : _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isVerifyingOtp
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Verify Phone',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSaving || !provider.phoneVerified
                                ? null
                                : _completeProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Complete Profile',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'You can safely sign out and return later. Your Google account remains linked to your RailSahayak profile.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
