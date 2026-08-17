import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../providers/request_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isStaff = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<bool> _verifySignupPhone(RequestProvider provider) async {
    final phone = _phoneController.text.trim();

    final sent = await provider.sendPhoneOtp(phone);
    if (!mounted) return false;

    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.phoneVerificationError ??
                'Could not send the verification code.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return false;
    }

    final otpController = TextEditingController();
    bool verifying = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Verify Phone Number'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Enter the 6-digit OTP for +91 $phone.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'OTP',
                      hintText: '123456',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      errorText: provider.phoneVerificationError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: verifying
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: verifying
                      ? null
                      : () async {
                          final otp = otpController.text.trim();
                          if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter the 6-digit OTP.'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => verifying = true);
                          final ok = await provider.verifyPhoneOtp(otp);

                          if (!mounted) return;

                          if (ok) {
                            Navigator.of(dialogContext).pop(true);
                          } else {
                            setDialogState(() => verifying = false);
                          }
                        },
                  child: verifying
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );

    otpController.dispose();
    return result == true && provider.phoneVerified;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );

    FocusScope.of(context).unfocus();

    final success = await provider.signup(
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      role: _isStaff ? UserRole.staff : UserRole.passenger,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not create account. The email or username may already be registered.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final phoneVerified = await _verifySignupPhone(provider);

    if (!mounted) return;

    if (!phoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone verification is required to finish signup.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final profileCompleted = await provider.completeProfile(
      username: _usernameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;

    if (!profileCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone verified, but the profile could not be finalized.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Account created and phone verified!'),
        backgroundColor: Colors.green.shade700,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<RequestProvider>().isLoading;

    final primaryColor =
        _isStaff ? Colors.indigo.shade800 : Colors.orange.shade800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Join RailSahayak',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Create your account to request railway assistance.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Passenger / Staff
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              value: false,
                              groupValue: _isStaff,
                              title: const Text('Passenger'),
                              onChanged: (_) {
                                setState(() {
                                  _isStaff = false;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              value: true,
                              groupValue: _isStaff,
                              title: const Text('Staff'),
                              onChanged: (_) {
                                setState(() {
                                  _isStaff = true;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Full Name
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Username
                      TextFormField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'Choose a username',
                          prefixIcon: Icon(Icons.alternate_email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final username = value?.trim() ?? '';

                          if (username.isEmpty) {
                            return 'Please choose a username';
                          }

                          if (username.length < 3) {
                            return 'Username must be at least 3 characters';
                          }

                          if (!RegExp(r'^[a-zA-Z0-9_]+$')
                              .hasMatch(username)) {
                            return 'Use only letters, numbers, and underscores';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isEmpty) {
                            return 'Please enter your email';
                          }

                          final emailRegex = RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          );

                          if (!emailRegex.hasMatch(email)) {
                            return 'Please enter a valid email address';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number (OTP verified)',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final phone = value?.trim() ?? '';

                          if (phone.isEmpty) {
                            return 'Please enter your phone number';
                          }

                          if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
                            return 'Enter a valid 10-digit phone number';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
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
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }

                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Confirm Password
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }

                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Create Account
                      ElevatedButton(
                        onPressed: isLoading ? null : _handleSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),

                      const SizedBox(height: 16),

                      // Back to Login
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text(
                          'Already have an account? Login',
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