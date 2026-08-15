import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/request_provider.dart';
import 'models/user_profile.dart';

import 'screens/auth/login_screen.dart';
import 'screens/passenger/passenger_home.dart';
import 'screens/staff/staff_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GoogleSignIn.instance.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => RequestProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();

    final currentUser = provider.currentUser;
    final needsProfileCompletion =
        provider.needsProfileCompletion;

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
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.4,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.3,
          ),
        ),

        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(12),
            ),
          ),
        ),
      ),

      home: _getHomeRoute(
        currentUser,
        needsProfileCompletion,
      ),
    );
  }

  Widget _getHomeRoute(
    UserProfile? user,
    bool needsProfileCompletion,
  ) {
    // -------------------------------------------------------
    // Not logged in
    // -------------------------------------------------------

    if (user == null) {
      return const LoginScreen();
    }

    // -------------------------------------------------------
    // Profile incomplete
    // -------------------------------------------------------

    if (needsProfileCompletion) {
      return const ProfileCompletionScreen();
    }

    // -------------------------------------------------------
    // Railway Staff
    // -------------------------------------------------------

    if (user.role == UserRole.staff) {
      return const StaffDashboard();
    }

    // -------------------------------------------------------
    // Passenger
    // -------------------------------------------------------

    return const PassengerHome();
  }
}

// ===========================================================================
// PROFILE COMPLETION SCREEN
// ===========================================================================

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({
    super.key,
  });

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController =
      TextEditingController();

  final _phoneController =
      TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final user =
        context.read<RequestProvider>().currentUser;

    if (user != null) {
      _usernameController.text =
          user.username;

      _phoneController.text =
          user.phone;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider =
        context.read<RequestProvider>();

    final user = provider.currentUser;

    if (user == null) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final username =
          _usernameController.text
              .trim()
              .toLowerCase();

      final phone =
          _phoneController.text
              .trim()
              .replaceAll(
                RegExp(r'[\s-]'),
                '',
              );

      // -------------------------------------------------------
      // Check username availability
      // -------------------------------------------------------

      final usernameQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .where(
                'username',
                isEqualTo: username,
              )
              .limit(1)
              .get();

      if (usernameQuery.docs.isNotEmpty &&
          usernameQuery.docs.first.id != user.id) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'That username is already taken.',
            ),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          _isSaving = false;
        });

        return;
      }

      // -------------------------------------------------------
      // Save profile to Firestore
      // -------------------------------------------------------

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .set(
        {
          'name': user.name,
          'username': username,
          'email': user.email,
          'phone': phone,
          'role': user.role == UserRole.staff
              ? 'staff'
              : 'passenger',
          'disabilityType':
              user.disabilityType,
          'preferredAssistance':
              user.preferredAssistance,
        },
        SetOptions(
          merge: true,
        ),
      );

      // -------------------------------------------------------
      // Update RequestProvider
      // -------------------------------------------------------

      await provider.completeProfile(
        username: username,
        phone: phone,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile completed successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // No manual navigation needed here.
      //
      // completeProfile() changes:
      //
      // needsProfileCompletion = false
      //
      // Provider notifies MyApp.
      //
      // MyApp rebuilds and automatically shows PassengerHome.
    } catch (e) {
      debugPrint(
        'Profile completion error: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save your profile. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<RequestProvider>();

    final user = provider.currentUser;

    final primaryColor =
        Colors.orange.shade800;

    return Scaffold(
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

        // Prevent going back to login.
        automaticallyImplyLeading: false,
      ),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 500,
            ),

            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(16),
              ),

              child: Padding(
                padding:
                    const EdgeInsets.all(24),

                child: Form(
                  key: _formKey,

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,

                    children: [
                      // -------------------------------------------------------
                      // Icon
                      // -------------------------------------------------------

                      CircleAvatar(
                        radius: 42,

                        backgroundColor:
                            primaryColor.withOpacity(
                          0.12,
                        ),

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
                          fontWeight:
                              FontWeight.bold,
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

                      // -------------------------------------------------------
                      // Google Account
                      // -------------------------------------------------------

                      if (user != null)
                        Container(
                          padding:
                              const EdgeInsets.all(16),

                          decoration:
                              BoxDecoration(
                            color:
                                Colors.grey.shade100,

                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),

                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [
                              const Text(
                                'Google Account',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              const SizedBox(
                                height: 8,
                              ),

                              Text(
                                user.name,

                                style:
                                    const TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),

                              const SizedBox(
                                height: 4,
                              ),

                              Text(
                                user.email,

                                style:
                                    const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // -------------------------------------------------------
                      // Username
                      // -------------------------------------------------------

                      TextFormField(
                        controller:
                            _usernameController,

                        enabled: !_isSaving,

                        textInputAction:
                            TextInputAction.next,

                        decoration:
                            InputDecoration(
                          labelText: 'Username',
                          hintText:
                              'Choose a username',

                          prefixIcon:
                              const Icon(
                            Icons.person_outline,
                          ),

                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),
                        ),

                        validator: (value) {
                          final username =
                              value?.trim() ?? '';

                          if (username.isEmpty) {
                            return 'Please enter a username';
                          }

                          if (username.length < 3) {
                            return 'Username must be at least 3 characters';
                          }

                          if (!RegExp(
                            r'^[a-zA-Z0-9_]+$',
                          ).hasMatch(username)) {
                            return 'Use only letters, numbers and _';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // -------------------------------------------------------
                      // Phone
                      // -------------------------------------------------------

                      TextFormField(
                        controller:
                            _phoneController,

                        enabled: !_isSaving,

                        keyboardType:
                            TextInputType.phone,

                        textInputAction:
                            TextInputAction.done,

                        onFieldSubmitted: (_) {
                          if (!_isSaving) {
                            _completeProfile();
                          }
                        },

                        decoration:
                            InputDecoration(
                          labelText:
                              'Phone Number',

                          hintText:
                              'Enter your 10-digit phone number',

                          prefixIcon:
                              const Icon(
                            Icons.phone_outlined,
                          ),

                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),
                        ),

                        validator: (value) {
                          final phone =
                              value?.trim() ?? '';

                          final cleanPhone =
                              phone.replaceAll(
                            RegExp(r'[\s-]'),
                            '',
                          );

                          if (cleanPhone.isEmpty) {
                            return 'Please enter your phone number';
                          }

                          if (!RegExp(
                            r'^[0-9]{10}$',
                          ).hasMatch(cleanPhone)) {
                            return 'Enter a valid 10-digit phone number';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 28),

                      // -------------------------------------------------------
                      // Complete Profile Button
                      // -------------------------------------------------------

                      SizedBox(
                        height: 52,

                        child: ElevatedButton(
                          onPressed:
                              _isSaving
                                  ? null
                                  : _completeProfile,

                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                primaryColor,

                            foregroundColor:
                                Colors.white,

                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                            ),
                          ),

                          child: _isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,

                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2.5,

                                    valueColor:
                                        AlwaysStoppedAnimation<
                                            Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Complete Profile',

                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Your information is stored securely with your RailSahayak account.',

                        textAlign:
                            TextAlign.center,

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
    );
  }
}