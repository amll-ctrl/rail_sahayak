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

  Future<List<Map<String, dynamic>>> _loadStaffRequests() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('staff_requests')
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<void> _refresh() async {
    setState(() => _staffFuture = _loadApprovedStaff());
    await _staffFuture;
    if (mounted) setState(() {});
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    final requestId = request['id']?.toString() ?? '';
    final email = (request['email'] ?? '').toString().trim().toLowerCase();
    final name = (request['name'] ?? '').toString().trim();
    final phone = (request['phone'] ?? '').toString().trim();

    if (requestId.isEmpty || email.isEmpty) return;

    try {
      final authMatches = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (authMatches.isNotEmpty && authMatches.contains('password')) {
        // The account already exists. The approved staff member can use their
        // existing password, so only create/update the authorized profile.
        User? firebaseUser = FirebaseAuth.instance.currentUser;
        final currentMatchesAdmin = firebaseUser != null &&
            firebaseUser.email?.toLowerCase() == email &&
            context.read<RequestProvider>().currentUser?.role == UserRole.admin;
        if (currentMatchesAdmin) {
          firebaseUser = null;
        }
        await FirebaseFirestore.instance.collection('staff_requests').doc(requestId).update({
          'status': 'approved',
        });
        // Without Admin SDK, the app cannot retrieve another user's UID from
        // the auth provider. The staff member should create/sign into the
        // Firebase account using the approved company email; a profile is
        // linked during the staff account bootstrap path below.
      } else {
        await FirebaseFirestore.instance.collection('staff_requests').doc(requestId).update({
          'status': 'approved',
        });
      }

      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email approved for RailSahayak staff access.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not approve staff request.'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not approve staff request: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance.collection('staff_requests').doc(requestId).update({
        'status': 'rejected',
      });
      if (mounted) setState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff request rejected.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reject request: $e'), backgroundColor: Colors.red),
      );
    }
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
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await context.read<RequestProvider>().logout();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
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
            const Text('Staff approval requests', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Approve a staff member before they can use the Railway Staff login.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadStaffRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
                }
                if (snapshot.hasError) {
                  return Card(child: ListTile(title: const Text('Could not load staff requests'), subtitle: Text('${snapshot.error}')));
                }
                final requests = snapshot.data ?? [];
                if (requests.isEmpty) {
                  return const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('No pending staff requests'), subtitle: Text('New staff access requests will appear here.')));
                }
                return Column(
                  children: requests.map((request) {
                    final name = (request['name'] ?? 'Railway Staff').toString();
                    final email = (request['email'] ?? '').toString();
                    final phone = (request['phone'] ?? '').toString();
                    final id = (request['id'] ?? '').toString();
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
                        title: Text(name),
                        subtitle: Text('$email\n${phone.isEmpty ? 'No phone listed' : phone}'),
                        isThreeLine: true,
                        trailing: Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Approve',
                              onPressed: () => _approveRequest(request),
                              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                            ),
                            IconButton(
                              tooltip: 'Reject',
                              onPressed: () => _rejectRequest(id),
                              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 22),
            const Text('Approved staff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<UserProfile>>(
              future: _staffFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
                }
                final staff = snapshot.data ?? [];
                if (staff.isEmpty) {
                  return const Card(child: ListTile(title: Text('No approved staff yet')));
                }
                return Column(
                  children: staff.map((member) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified_user_outlined, color: Colors.green),
                      title: Text(member.name.isEmpty ? 'Railway Staff' : member.name),
                      subtitle: Text('${member.email}\n${member.phone.isEmpty ? 'No phone listed' : member.phone}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Send password reset email',
                        onPressed: member.email.isEmpty ? null : () => _resetPassword(member.email),
                        icon: const Icon(Icons.key_outlined),
                      ),
                    ),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Spark-plan staff security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Staff approval is stored in Firestore. The staff member must use the approved company email for Firebase Authentication. Passwords are never stored in Firestore.', style: TextStyle(color: Colors.grey)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
