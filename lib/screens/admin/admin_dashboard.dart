import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    _staffFuture = _loadApprovedStaff();
  }

  Future<List<UserProfile>> _loadApprovedStaff() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'staff')
        .get();
    return snapshot.docs
        .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> _refresh() async {
    final provider = context.read<RequestProvider>();
    await provider.refreshAdminData();
    if (!mounted) return;
    setState(() => _staffFuture = _loadApprovedStaff());
    await _staffFuture;
  }

  Future<void> _resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email'), backgroundColor: Colors.green.shade700),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not send password reset email.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    try {
      // Clear the app state first, then explicitly terminate the Firebase
      // session. This avoids waiting for background listeners before the app
      // returns to its unauthenticated route.
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

  Widget _staffTile(UserProfile staff, {bool pending = false}) {
    final provider = context.read<RequestProvider>();
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: pending ? Colors.orange.shade50 : Colors.green.shade50,
          child: Icon(Icons.badge_outlined, color: pending ? Colors.orange.shade800 : Colors.green.shade700),
        ),
        title: Text(staff.name.isNotEmpty ? staff.name : 'Railway Staff'),
        subtitle: Text('${staff.email}\n${staff.phone.isNotEmpty ? staff.phone : 'No phone listed'}'),
        isThreeLine: true,
        trailing: pending
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Approve staff',
                    onPressed: () async {
                      await provider.approveStaff(staff.id);
                      if (mounted) setState(() => _staffFuture = _loadApprovedStaff());
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    color: Colors.green,
                  ),
                  IconButton(
                    tooltip: 'Reject account',
                    onPressed: () async {
                      await provider.rejectStaff(staff.id);
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    color: Colors.red,
                  ),
                ],
              )
            : IconButton(
                tooltip: 'Send password reset email',
                onPressed: () => _resetPassword(staff.email),
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
          IconButton(tooltip: 'Refresh', onPressed: provider.isAdminDataLoading || _loggingOut ? null : _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.logout),
          ),
        ],
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
            const Text('Approve railway staff and manage their company login access.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            if (provider.adminStaffCandidates.isNotEmpty) ...[
              const Text('Pending approval', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...provider.adminStaffCandidates.map((staff) => _staffTile(staff, pending: true)),
              const SizedBox(height: 14),
            ],
            const Text('Approved staff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
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
                  return const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('No approved staff yet'), subtitle: Text('Approved staff accounts will appear here.')));
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
                  const Text('Staff sign in with their approved company email and Firebase password. Actual passwords are never displayed or stored in Firestore.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(children: [Icon(Icons.email_outlined, size: 20, color: Colors.indigo.shade700), const SizedBox(width: 8), const Expanded(child: Text('Use “Reset password” to send a secure password-reset email.'))]),
                ]),
              ),
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Requests overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Total live requests: ${provider.staffRequests.length}'),
                  const SizedBox(height: 6),
                  const Text('The admin can monitor the same live Firestore request data used by railway staff.', style: TextStyle(color: Colors.grey)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
