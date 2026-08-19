import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../admin/admin_dashboard.dart';

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
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      final firebaseUser = credential.user;
      if (firebaseUser == null) throw FirebaseAuthException(code: 'no-user', message: 'Firebase did not return an authenticated user.');
      final adminDoc = await FirebaseFirestore.instance.collection('admin').doc(firebaseUser.uid).get();
      if (!adminDoc.exists || adminDoc.data() == null) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(code: 'admin-profile-missing', message: 'This Firebase account is not registered as a RailSahayak administrator.');
      }
      final data = adminDoc.data()!;
      final role = (data['role'] ?? '').toString().trim().toLowerCase();
      final approved = data['approved'] == true || data['approved'].toString().trim().toLowerCase() == 'true';
      if (role != 'admin' || !approved) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(code: 'not-admin', message: 'This account is not an approved RailSahayak administrator.');
      }
      final provider = context.read<RequestProvider>();
      await provider.setAdminSession(uid: firebaseUser.uid, data: data);
      if (!mounted) return;
      if (provider.currentUser == null) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(code: 'admin-session-error', message: 'The administrator profile could not be loaded into the app.');
      }
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AdminDashboard()), (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyAuthError(e)), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 5)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Administrator login failed: $e'), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 5)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'The administrator email or password is incorrect.';
      case 'invalid-email':
        return 'Please enter a valid administrator email address.';
      case 'user-disabled':
        return 'This administrator account has been disabled in Firebase.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Authentication.';
      case 'too-many-requests':
        return 'Too many login attempts. Please wait a little and try again.';
      case 'admin-profile-missing':
      case 'not-admin':
      case 'admin-session-error':
        return e.message ?? 'Administrator authorization failed.';
      default:
        return e.message ?? 'Administrator login failed.';
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your administrator email first.')));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset email sent to $email'), backgroundColor: Colors.green.shade700));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyAuthError(e)), backgroundColor: Colors.red.shade700));
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFC62828);
    const lightRed = Color(0xFFFFEBEE);
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      appBar: AppBar(title: const Text('Administrator Login'), backgroundColor: primary, foregroundColor: Colors.white),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 5,
              color: const Color(0xFFFFF4EC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CircleAvatar(radius: 38, backgroundColor: lightRed, child: Icon(Icons.admin_panel_settings, size: 42, color: primary)),
                      const SizedBox(height: 18),
                      const Text('RailSahayak Administration', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 7),
                      const Text('Authorized administrators only', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 26),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_loading,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Administrator Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid administrator email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_loading,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off)), border: const OutlineInputBorder()),
                        validator: (value) => value == null || value.isEmpty ? 'Enter your password' : null,
                      ),
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _loading ? null : _forgotPassword, child: const Text('Forgot password?'))),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _login,
                          style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                          icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login),
                          label: Text(_loading ? 'Signing in...' : 'Secure Admin Login', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton.icon(onPressed: _loading ? null : () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back, color: primary), label: const Text('Back to passenger / staff login', style: TextStyle(color: primary))),
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
