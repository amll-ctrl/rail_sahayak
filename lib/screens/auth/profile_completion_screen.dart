import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
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
  bool _saving = false;

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
    super.dispose();
  }

  Future<void> _complete() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    final provider = context.read<RequestProvider>();
    final user = provider.currentUser;
    if (user == null) return;

    final username = _usernameController.text.trim().toLowerCase();
    final phone = _phoneController.text.replaceAll(RegExp(r'[\s-]'), '');

    setState(() => _saving = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final existing = await firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty && existing.docs.first.id != user.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That username is already taken.')),
          );
        }
        return;
      }

      final authUser = FirebaseAuth.instance.currentUser;
      final name = user.name.trim().isNotEmpty
          ? user.name.trim()
          : ((authUser?.displayName ?? '').trim().isNotEmpty
              ? authUser!.displayName!.trim()
              : (provider.pendingGoogleName.trim().isNotEmpty
                  ? provider.pendingGoogleName.trim()
                  : 'RailSahayak User'));
      final email = user.email.trim().isNotEmpty
          ? user.email.trim().toLowerCase()
          : (authUser?.email ?? provider.pendingGoogleEmail).trim().toLowerCase();

      // Save the complete passenger profile, including the Google-provided
      // name/email. Previously only username and phone were saved, which is
      // why the dashboard later showed "Welcome, !".
      await firestore.collection('users').doc(user.id).set({
        'name': name,
        'username': username,
        'email': email,
        'phone': phone,
        'role': 'passenger',
        'disabilityType': user.disabilityType,
        'preferredAssistance': user.preferredAssistance,
      }, SetOptions(merge: true));

      if (authUser != null && name.isNotEmpty && authUser.displayName != name) {
        try {
          await authUser.updateDisplayName(name);
        } catch (_) {
          // Firestore remains the source of truth for the RailSahayak profile.
        }
      }

      // Keep the Firebase session alive and immediately promote the completed
      // profile into RequestProvider. Do NOT log the user out and force a
      // second login.
      final completedProfile = UserProfile(
        id: user.id,
        name: name,
        username: username,
        email: email,
        phone: phone,
        role: UserRole.passenger,
        disabilityType: user.disabilityType,
        preferredAssistance: user.preferredAssistance,
      );

      await provider.completePassengerSignupSession(completedProfile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save your profile. Please try again. ($e)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final user = provider.currentUser;
    final primary = Colors.orange.shade800;
    final displayName = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : (provider.pendingGoogleName.trim().isNotEmpty
            ? provider.pendingGoogleName.trim()
            : 'Google Account');
    final displayEmail = (user?.email.trim().isNotEmpty ?? false)
        ? user!.email.trim()
        : provider.pendingGoogleEmail.trim();

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
            onPressed: provider.isLoading || _saving ? null : () => provider.logout(),
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
                      const Text('Almost there!', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(displayName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                      if (displayEmail.isNotEmpty)
                        Text(displayEmail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameController,
                        enabled: !_saving,
                        decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                        validator: (value) {
                          final username = value?.trim() ?? '';
                          if (username.length < 3) return 'Username must be at least 3 characters.';
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) return 'Use only letters, numbers and _';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !_saving,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '10-digit Indian mobile number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (value) => RegExp(r'^[0-9]{10}$').hasMatch(value?.trim() ?? '') ? null : 'Enter a valid 10-digit phone number.',
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _complete,
                          style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                          child: _saving
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
