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

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSendingOtp = false;
  bool _isCompleting = false;

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

  Future<bool> _verifyPhone(RequestProvider provider) async {
    final phone = _phoneController.text.trim();

    setState(() => _isSendingOtp = true);
    final sent = await provider.sendPhoneOtp(phone);
    if (!mounted) return false;
    setState(() => _isSendingOtp = false);

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
                  Text('Enter the 6-digit OTP for +91 ${phone.replaceAll(RegExp(r'\D'), '')}.'),
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

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<RequestProvider>();
    FocusScope.of(context).unfocus();

    setState(() => _isCompleting = true);

    try {
      final success = await provider.signup(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        role: UserRole.passenger,
      );

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not create the passenger account. The email or username may already be registered.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final verified = await _verifyPhone(provider);
      if (!mounted) return;

      if (!verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone verification is required to finish registration.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final completed = await provider.completeProfile(
        username: _usernameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (!mounted) return;

      if (!completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone verified, but the profile could not be finalized.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Passenger account created and phone verified!'),
          backgroundColor: Colors.green.shade700,
        ),
      );

      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<RequestProvider>().isLoading ||
        _isSendingOtp ||
        _isCompleting;
    final primaryColor = Colors.orange.shade800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Passenger Account',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
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
                      const Text(
                        'Join RailSahayak',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a passenger account to request railway assistance.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please enter your name'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _usernameController,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.alternate_email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final username = value?.trim() ?? '';
                          if (username.length < 3) return 'Username must be at least 3 characters';
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
                            return 'Use only letters, numbers and _';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '10-digit Indian mobile number',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final phone = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
                          if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
                            return 'Enter a valid 10-digit phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !isLoading,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() {
                              _obscurePassword = !_obscurePassword;
                            }),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.length < 6)
                                ? 'Password must be at least 6 characters'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !isLoading,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            }),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => value != _passwordController.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleSignup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: _isCompleting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Create Passenger Account',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Railway staff accounts require separate authorization and are not created here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
