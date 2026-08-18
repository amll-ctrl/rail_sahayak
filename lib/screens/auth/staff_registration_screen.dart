import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StaffRegistrationScreen extends StatefulWidget {
  const StaffRegistrationScreen({super.key});

  @override
  State<StaffRegistrationScreen> createState() => _StaffRegistrationScreenState();
}

class _StaffRegistrationScreenState extends State<StaffRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.replaceAll(RegExp(r'[\s-]'), '');
    final name = _nameController.text.trim();

    try {
      final existing = await FirebaseFirestore.instance
          .collection('staff_requests')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        _show('A staff request for this email already exists.', isError: true);
        return;
      }

      await FirebaseFirestore.instance.collection('staff_requests').add({
        'name': name,
        'email': email,
        'phone': phone,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _show('Staff request submitted. An administrator must approve it before you can use Staff Login.');
      if (mounted) Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      _show(e.message ?? 'Could not submit the staff request.', isError: true);
    } catch (e) {
      _show('Could not submit the staff request: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF283593);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Railway Staff Registration'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
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
                      const Icon(Icons.badge_outlined, size: 60, color: primary),
                      const SizedBox(height: 12),
                      const Text('Request Staff Access', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Submit your RailSahayak staff details. The administrator will review and approve your request before login is enabled.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        enabled: !_loading,
                        decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_loading,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'RailSahayak Company Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                        validator: (v) {
                          final email = v?.trim() ?? '';
                          return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? null : 'Enter a valid email address';
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !_loading,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder()),
                        validator: (v) => RegExp(r'^\d{10}$').hasMatch((v ?? '').replaceAll(RegExp(r'[\s-]'), '')) ? null : 'Enter a valid 10-digit phone number',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_loading,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(labelText: 'Desired Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off)), border: const OutlineInputBorder()),
                        validator: (v) => v == null || v.length < 6 ? 'Use at least 6 characters' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !_loading,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(labelText: 'Confirm Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm), icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off)), border: const OutlineInputBorder()),
                        validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          style: FilledButton.styleFrom(backgroundColor: primary),
                          icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                          label: Text(_loading ? 'Submitting...' : 'Submit for Approval'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Your password is only used locally to help you prepare your account. It is not stored in the staff request. After approval, you will create or reset your Firebase password using the approved company email.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
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
