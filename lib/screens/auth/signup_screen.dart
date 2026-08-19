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
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
        return;
      }

      // Firebase automatically signs the user in after account creation, but
      // RequestProvider still needs to hydrate the Firestore profile using the
      // real Firebase UID. Do that directly instead of first creating a
      // temporary in-memory profile with an empty ID.
      final success = await provider.login(
        _emailController.text.trim(),
        _passwordController.text,
        false,
      );
      if (!mounted) return;
      if (!success) {
        final message = provider.lastLoginError ??
            'Account was created, but the session could not be initialized. Please log in.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.orange),
        );
        return;
      }

      // main.dart reacts to the provider session and opens the passenger home.
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<RequestProvider>().isLoading || _isCompleting;
    final primaryColor = Colors.orange.shade800;
    InputDecoration deco(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder());
    return Scaffold(
      appBar: AppBar(title: const Text('Create Passenger Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: primaryColor, foregroundColor: Colors.white, centerTitle: true),
      body: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(padding: const EdgeInsets.all(24), child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Join RailSahayak', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Create a passenger account to request railway assistance.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              TextFormField(controller: _nameController, enabled: !isLoading, decoration: deco('Full Name', Icons.person_outline), validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _usernameController, enabled: !isLoading, decoration: deco('Username', Icons.alternate_email), validator: (v) { final x = v?.trim() ?? ''; return x.length < 3 ? 'Username must be at least 3 characters' : (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(x) ? 'Use only letters, numbers and _' : null); }),
              const SizedBox(height: 16),
              TextFormField(controller: _emailController, enabled: !isLoading, keyboardType: TextInputType.emailAddress, decoration: deco('Email', Icons.email_outlined), validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email address'),
              const SizedBox(height: 16),
              TextFormField(controller: _phoneController, enabled: !isLoading, keyboardType: TextInputType.phone, decoration: deco('Phone Number', Icons.phone_outlined), validator: (v) => RegExp(r'^[0-9]{10}$').hasMatch((v ?? '').replaceAll(RegExp(r'[\s-]'), '')) ? null : 'Enter a valid 10-digit phone number'),
              const SizedBox(height: 16),
              TextFormField(controller: _passwordController, enabled: !isLoading, obscureText: _obscurePassword, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscurePassword = !_obscurePassword),), border: const OutlineInputBorder()), validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _confirmPasswordController, enabled: !isLoading, obscureText: _obscureConfirmPassword, decoration: InputDecoration(labelText: 'Confirm Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),), border: const OutlineInputBorder()), validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null),
              const SizedBox(height: 24),
              SizedBox(height: 52, child: ElevatedButton(onPressed: isLoading ? null : _handleSignup, style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white), child: _isCompleting ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Passenger Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 12),
              const Text('Railway staff accounts require separate authorization and are not created here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          )),
        )),
      )),
    );
  }
}
