import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_functions/firebase_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../providers/request_provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Future<List<UserProfile>>? _staffFuture;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _staffFuture = _loadStaff();
  }

  Future<List<UserProfile>> _loadStaff() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'staff')
        .get();
    return snapshot.docs
        .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> _refresh() async {
    setState(() => _staffFuture = _loadStaff());
    await _staffFuture;
  }

  Future<void> _resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not send password reset email.'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send password reset email: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showCreateStaffDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    bool creating = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: !creating,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create RailSahayak Staff Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('This creates a real Firebase staff account that can immediately use Staff Login.'),
                const SizedBox(height: 14),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Staff name', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Company email', hintText: 'name@railsahayak.com', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number (optional)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary password', helperText: 'At least 6 characters', border: OutlineInputBorder())),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: creating ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: creating
                  ? null
                  : () async {
                      setDialogState(() {
                        creating = true;
                        error = null;
                      });
                      try {
                        final callable = FirebaseFunctions.instance.httpsCallable('createStaffAccount');
                        await callable.call({
                          'name': nameController.text.trim(),
                          'email': emailController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'password': passwordController.text,
                        });
                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        setState(() => _staffFuture = _loadStaff());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Staff account created and approved successfully.')),
                        );
                      } on FirebaseFunctionsException catch (e) {
                        setDialogState(() {
                          creating = false;
                          error = e.message ?? 'Could not create the staff account.';
                        });
                      } catch (e) {
                        setDialogState(() {
                          creating = false;
                          error = 'Could not create the staff account: $e';
                        });
                      }
                    },
              icon: creating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.person_add_alt_1),
              label: Text(creating ? 'Creating...' : 'Create account'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await context.read<RequestProvider>().logout();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sign out: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Widget _staffTile(UserProfile staff) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: Icon(Icons.badge_outlined, color: Colors.green.shade700),
        ),
        title: Text(staff.name.isNotEmpty ? staff.name : 'Railway Staff'),
        subtitle: Text('${staff.email}\n${staff.phone.isNotEmpty ? staff.phone : 'No phone listed'}'),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Send password reset email',
          onPressed: staff.email.isEmpty ? null : () => _resetPassword(staff.email),
          icon: const Icon(Icons.key_outlined),
          color: Colors.indigo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final user = provider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RailSahayak Admin', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loggingOut ? null : _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateStaffDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Create Staff'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: Colors.indigo.shade800,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.admin_panel_settings, color: Colors.white, size: 34),
                  const SizedBox(height: 12),
                  Text(user?.name.isNotEmpty == true ? user!.name : 'Administrator', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(user?.email ?? '', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  const Text('ADMINISTRATOR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ]),
              ),
            ),
            const SizedBox(height: 22),
            const Text('Staff Management', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Create approved RailSahayak staff accounts. Each account receives a real Firebase login and can access only the Staff Dashboard.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 14),
            FutureBuilder<List<UserProfile>>(
              future: _staffFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
                }
                if (snapshot.hasError) {
                  return Card(child: ListTile(title: const Text('Could not load staff'), subtitle: Text('${snapshot.error}')));
                }
                final staff = snapshot.data ?? [];
                if (staff.isEmpty) {
                  return const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('No staff accounts yet'), subtitle: Text('Tap Create Staff to create and approve the first staff account.')));
                }
                return Column(children: staff.map(_staffTile).toList());
              },
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Staff login security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Staff sign in with the company email and password created by the administrator. Passwords are handled by Firebase Authentication and are never displayed or stored in Firestore.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(children: [Icon(Icons.email_outlined, size: 20, color: Colors.indigo), const SizedBox(width: 8), const Expanded(child: Text('Use Reset Password to send a secure password-reset email.'))]),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
