import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../providers/request_provider.dart';
import '../../providers/request_provider_signup.dart';

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

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<RequestProvider>();
    FocusScope.of(context).unfocus();
    setState(() => _isCompleting = true);

    try {
      final error = await provider.signup(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        role: UserRole.passenger,
      );

      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      await provider.logout();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Passenger account created successfully! You can now log in.'),
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
    final isLoading = context.watch<RequestProvider>().isLoading || _isCompleting;
    final primaryColor = Colors.orange.shade800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Passenger Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Join RailSahayak', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('Create a passenger account to request railway assistance.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                      TextFormField(controller: _nameController, enabled: !isLoading, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()), validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your name' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _usernameController, enabled: !isLoading, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email), border: OutlineInputBorder()), validator: (value) { final username = value?.trim() ?? ''; if (username.length < 3) return 'Username must be at least 3 characters'; if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) return 'Use only letters, numbers and _'; return null; }),
                      const SizedBox(height: 16),
                      TextFormField(controller: _emailController, enabled: !isLoading, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()), validator: (value) { final email = value?.trim() ?? ''; return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? null : 'Enter a valid email address'; }),
                      const SizedBox(height: 16),
                      TextFormField(controller: _phoneController, enabled: !isLoading, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Phone Number', hintText: '10-digit Indian mobile number', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder()), validator: (value) { final phone = (value ?? '').replaceAll(RegExp(r'[\s-]'), ''); return RegExp(r'^[0-9]{10}$').hasMatch(phone) ? null : 'Enter a valid 10-digit phone number'; }),
                      const SizedBox(height: 16),
                      TextFormField(controller: _passwordController, enabled: !isLoading, obscureText: _obscurePassword, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)), border: const OutlineInputBorder()), validator: (value) => value == null || value.length < 6 ? 'Password must be at least 6 characters' : null),
                      const SizedBox(height: 16),
                      TextFormField(controller: _confirmPasswordController, enabled: !isLoading, obscureText: _obscureConfirmPassword, textInputAction: TextInputAction.done, decoration: InputDecoration(labelText: 'Confirm Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)), border: const OutlineInputBorder()), validator: (value) => value != _passwordController.text ? 'Passwords do not match' : null),
                      const SizedBox(height: 24),
                      SizedBox(height: 52, child: ElevatedButton(onPressed: isLoading ? null : _handleSignup, style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white), child: _isCompleting ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Passenger Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
                      const SizedBox(height: 12),
                      const Text('Railway staff accounts require separate authorization and are not created here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
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
