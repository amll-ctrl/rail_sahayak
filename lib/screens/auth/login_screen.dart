import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/request_provider.dart';
import 'admin_login_screen.dart';
import 'signup_screen.dart';
import 'staff_registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isStaff = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final provider = context.read<RequestProvider>();
    final success = await provider.login(
      _identifierController.text.trim(),
      _passwordController.text,
      _isStaff,
    );

    if (!mounted) return;
    if (!success) {
      final message = provider.lastLoginError ??
          (_isStaff
              ? 'Staff login failed.'
              : 'Incorrect email/username or password.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    FocusScope.of(context).unfocus();
    final provider = context.read<RequestProvider>();
    final success = await provider.signInWithGoogle(isStaff: _isStaff);

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isStaff
              ? 'Google staff login is only available for an already approved staff account.'
              : 'Google sign-in failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final loading = provider.isLoading;
    final primary = _isStaff ? Colors.indigo.shade800 : Colors.orange.shade800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RailSahayak - Accessibility',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primary,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.indigo.shade100),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: loading
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                                ),
                        child: const Row(
                          children: [
                            Icon(Icons.admin_panel_settings, color: Color(0xFF283593), size: 30),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Administrator Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  SizedBox(height: 2),
                                  Text('Authorized admin access only', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Color(0xFF283593)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text('Welcome to RailSahayak', textAlign: TextAlign.center, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text('Sign in to request or provide railway assistance.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 22),
                    Container(
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: loading ? null : () => setState(() => _isStaff = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(color: !_isStaff ? Colors.orange.shade800 : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                                child: Text('Passenger', textAlign: TextAlign.center, style: TextStyle(color: !_isStaff ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: loading ? null : () => setState(() => _isStaff = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(color: _isStaff ? Colors.indigo.shade800 : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                                child: Text('Railway Staff', textAlign: TextAlign.center, style: TextStyle(color: _isStaff ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _identifierController,
                            enabled: !loading,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(labelText: _isStaff ? 'Company Email' : 'Email or Username', prefixIcon: const Icon(Icons.person_outline), border: const OutlineInputBorder()),
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return _isStaff ? 'Please enter your company email' : 'Please enter your email or username';
                              if (v.contains('@') && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Enter a valid email address';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !loading,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => loading ? null : _handleLogin(),
                            decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off)), border: const OutlineInputBorder()),
                            validator: (value) => value == null || value.isEmpty ? 'Please enter your password' : null,
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: loading ? null : _handleLogin,
                              style: FilledButton.styleFrom(backgroundColor: primary),
                              child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Login Securely', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: loading ? null : _handleGoogleSignIn,
                            icon: Icon(Icons.account_circle, color: primary),
                            label: Text('Continue with Google', style: TextStyle(color: primary)),
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), side: BorderSide(color: primary)),
                          ),
                          if (!_isStaff) ...[
                            const SizedBox(height: 18),
                            const Divider(),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: loading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Create Passenger Account', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ] else ...[
                            const SizedBox(height: 14),
                            const Text('Staff accounts must be approved by an administrator before they can sign in.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: loading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StaffRegistrationScreen())),
                              icon: const Icon(Icons.badge_outlined),
                              label: const Text('Request Staff Access'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
