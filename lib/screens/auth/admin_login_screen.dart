import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/request_provider.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final provider = context.read<RequestProvider>();
    final success = await provider.login(
      _emailController.text.trim(),
      _passwordController.text,
      false,
    );

    if (!mounted) return;
    if (!success || provider.currentUser?.role.name != 'admin') {
      await provider.logout();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid administrator credentials.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<RequestProvider>().isLoading;
    const primary = Color(0xFF283593);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Login'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CircleAvatar(
                        radius: 38,
                        backgroundColor: Color(0xFFE8EAF6),
                        child: Icon(Icons.admin_panel_settings, size: 42, color: primary),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'RailSahayak Administration',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Authorized administrators only',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 26),
                      TextFormField(
                        controller: _emailController,
                        enabled: !loading,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Administrator Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                            return 'Enter a valid administrator email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !loading,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Enter your password' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: loading ? null : _login,
                          style: FilledButton.styleFrom(backgroundColor: primary),
                          icon: loading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.login),
                          label: const Text('Secure Admin Login', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: loading ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to passenger / staff login'),
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
