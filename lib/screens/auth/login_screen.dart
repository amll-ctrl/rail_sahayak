import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isStaff = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final provider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );

    try {
      final success = await provider.login(
        _emailController.text.trim(),
        _passwordController.text,
        _isStaff,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged in as ${provider.currentUser?.name ?? 'User'}',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Incorrect username/email or password.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incorrect username/email or password.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }


  Future<void> _handleGoogleSignIn() async {
    FocusScope.of(context).unfocus();

    final provider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );

    final success = await provider.signInWithGoogle(
      isStaff: _isStaff,
    );

    if (!mounted) return;

    if (success) {
      final user = provider.currentUser;

      final needsProfile = provider.needsProfileCompletion;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            needsProfile
                ? 'Google account connected. Please complete your profile.'
                : 'Welcome ${user?.name ?? 'User'}!',
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );

      // Do NOT navigate directly to PassengerHome here.
      // MyApp watches RequestProvider and will automatically route to:
      //   - ProfileCompletionScreen when the Google profile is incomplete
      //   - PassengerHome when the profile is complete
      // This prevents the phone/profile screen from flashing and being skipped.
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google sign-in failed. Please try again.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<RequestProvider>().isLoading;

    final primaryColor =
        _isStaff ? Colors.indigo.shade800 : Colors.orange.shade800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RailSahayak - Accessibility',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Indian Railways Tricolour Accent
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 30,
                              height: 6,
                              color: Colors.orange,
                            ),
                            Container(
                              width: 30,
                              height: 6,
                              color: Colors.white,
                            ),
                            Container(
                              width: 30,
                              height: 6,
                              color: Colors.green,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'RailSahayak',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 4),

                        const Text(
                          'Indian Railways Boarding Assistance App',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Passenger / Staff Switch
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _isStaff = false;
                                          });
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !_isStaff
                                          ? Colors.orange.shade800
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Passenger',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: !_isStaff
                                            ? Colors.white
                                            : const Color(0xFF212121),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _isStaff = true;
                                          });
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isStaff
                                          ? Colors.indigo.shade800
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Railway Staff',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _isStaff
                                            ? Colors.white
                                            : const Color(0xFF212121),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Email OR Username
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Email or Username',
                            hintText: 'Enter your email or username',
                            prefixIcon:
                                const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            final identifier = value?.trim() ?? '';

                            if (identifier.isEmpty) {
                              return 'Please enter your email or username';
                            }

                            if (identifier.contains('@')) {
                              final emailRegex = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              );

                              if (!emailRegex.hasMatch(identifier)) {
                                return 'Please enter a valid email address';
                              }
                            } else {
                              if (identifier.length < 3) {
                                return 'Username must be at least 3 characters';
                              }

                              if (!RegExp(
                                r'^[a-zA-Z0-9_]+$',
                              ).hasMatch(identifier)) {
                                return 'Username can only contain letters, numbers and _';
                              }
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!isLoading) {
                              _handleLogin();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword =
                                      !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Login Button
                        ElevatedButton(
                          onPressed: isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
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
                                  'Login Securely',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Google Sign-In
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed:
                                isLoading ? null : _handleGoogleSignIn,
                            icon: Icon(
                              Icons.account_circle,
                              size: 26,
                              color: primaryColor,
                            ),
                            label: Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(
                                color: primaryColor,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Sign Up
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const SignupScreen(),
                                    ),
                                  );
                                },
                          child: const Text(
                            "Don't have an account? Sign Up",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

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