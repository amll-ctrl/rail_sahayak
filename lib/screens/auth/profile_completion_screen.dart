import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/request_provider.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<RequestProvider>();
    final user = provider.currentUser;
    _usernameController.text = user?.username ?? '';
    _phoneController.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number.')),
      );
      return;
    }

    final ok = await context.read<RequestProvider>().sendPhoneOtp(phone);
    if (!mounted) return;
    if (ok) {
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent to your phone.')),
      );
    } else {
      final error = context.read<RequestProvider>().phoneVerificationError ??
          'Could not send OTP. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _verifyOtp() async {
    final ok = await context.read<RequestProvider>().verifyPhoneOtp(
          _otpController.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number verified.')),
      );
    } else {
      final error = context.read<RequestProvider>().phoneVerificationError ??
          'Incorrect OTP. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _complete() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<RequestProvider>().completeProfile(
          username: _usernameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
    if (!mounted) return;
    if (!ok) {
      final error = context.read<RequestProvider>().phoneVerificationError ??
          'Complete phone verification before continuing.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final user = provider.currentUser;
    final primary = Colors.orange.shade800;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('Complete Your Profile'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: provider.isLoading ? null : () => provider.logout(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.person_outline, size: 64),
                      const SizedBox(height: 16),
                      const Text('Almost there!', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (user != null) ...[
                        Text(user.name, textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(user.email, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                      ],
                      TextFormField(
                        controller: _usernameController,
                        enabled: !provider.isLoading,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final username = value?.trim() ?? '';
                          if (username.length < 3) return 'Username must be at least 3 characters.';
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
                            return 'Use only letters, numbers and _';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !provider.isLoading && !provider.phoneVerified,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          border: const OutlineInputBorder(),
                          suffixIcon: provider.phoneVerified
                              ? const Icon(Icons.verified, color: Colors.green)
                              : TextButton(onPressed: provider.phoneVerificationInProgress ? null : _sendOtp,
                                  child: const Text('SEND OTP')),
                        ),
                        validator: (value) => RegExp(r'^[0-9]{10}$').hasMatch(value?.trim() ?? '')
                            ? null : 'Enter a valid 10-digit phone number.',
                      ),
                      if (_otpSent && !provider.phoneVerified) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: '6-digit OTP',
                            border: const OutlineInputBorder(),
                            suffixIcon: TextButton(onPressed: provider.phoneVerificationInProgress ? null : _verifyOtp,
                                child: const Text('VERIFY')),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: provider.isLoading ? null : _complete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                          ),
                          child: provider.isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Complete Profile'),
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
