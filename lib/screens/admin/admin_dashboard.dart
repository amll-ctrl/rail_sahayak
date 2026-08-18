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
  Future<List<Map<String, dynamic>>>? _requestsFuture;
  final Set<String> _busyRequestIds = <String>{};
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _staffFuture = _loadApprovedStaff();
    _requestsFuture = _loadStaffRequests();
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
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  Future<void> _refresh() async {
    final staffFuture = _loadApprovedStaff();
    final requestsFuture = _loadStaffRequests();
    if (mounted) {
      setState(() {
        _staffFuture = staffFuture;
        _requestsFuture = requestsFuture;
      });
    }
    await Future.wait([staffFuture, requestsFuture]);
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    final requestId = request['id']?.toString() ?? '';
    final uid = request['uid']?.toString().trim() ?? '';
    final email = (request['email'] ?? '').toString().trim().toLowerCase();
    final name = (request['name'] ?? '').toString().trim();
    final phone = (request['phone'] ?? '').toString().trim();

    if (requestId.isEmpty || uid.isEmpty || email.isEmpty || _busyRequestIds.contains(requestId)) {
      if (mounted && uid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This staff request has no Firebase account ID. Ask the staff member to submit a new request.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _busyRequestIds.add(requestId));

    try {
      // The staff account was created during registration. Approval now links
      // that Auth UID to the real staff profile used by the rest of the app.
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'id': uid,
        'name': name.isEmpty ? 'Railway Staff' : name,
        'username': email.split('@').first.toLowerCase(),
        'email': email,
        'phone': phone,
        'role': 'staff',
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('staff_requests')
          .doc(requestId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedUid': uid,
      });

      if (!mounted) return;
      final requestsFuture = _loadStaffRequests();
      final staffFuture = _loadApprovedStaff();
      setState(() {
        _requestsFuture = requestsFuture;
        _staffFuture = staffFuture;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email approved for RailSahayak staff access.')),
      );
      await Future.wait([requestsFuture, staffFuture]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not approve staff request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyRequestIds.remove(requestId));
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    if (requestId.isEmpty || _busyRequestIds.contains(requestId)) return;
    setState(() => _busyRequestIds.add(requestId));

    try {
      await FirebaseFirestore.instance
          .collection('staff_requests')
          .doc(requestId)
          .update({'status': 'rejected'});

      if (!mounted) return;
      final requestsFuture = _loadStaffRequests();
      setState(() => _requestsFuture = requestsFuture);
      await requestsFuture;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not reject request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyRequestIds.remove(requestId));
    }
  }

  Future<void> _resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Could not send password reset email.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loggingOut ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
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
              color: Colors.indigo,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.admin_panel_settings, color: Colors.white, size: 34),
                    const SizedBox(height: 12),
                    Text(
                      user?.name.isNotEmpty == true ? user!.name : 'Administrator',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(user?.email ?? '', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Staff approval requests', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _requestsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
                }
                final requests = snapshot.data ?? [];
                if (requests.isEmpty) return const Card(child: ListTile(title: Text('No pending staff requests')));
                return Column(
                  children: requests.map((request) {
                    final id = request['id']?.toString() ?? '';
                    final busy = _busyRequestIds.contains(id);
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
                        title: Text(request['name']?.toString().isNotEmpty == true ? request['name'].toString() : 'Railway Staff'),
                        subtitle: Text('${request['email'] ?? ''}\n${request['phone'] ?? 'No phone'}'),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Reject',
                              onPressed: busy ? null : () => _rejectRequest(id),
                              icon: const Icon(Icons.close, color: Colors.red),
                            ),
                            IconButton(
                              tooltip: 'Approve',
                              onPressed: busy ? null : () => _approveRequest(request),
                              icon: busy
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.check_circle, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('Approved staff', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FutureBuilder<List<UserProfile>>(
              future: _staffFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
                }
                final staff = snapshot.data ?? [];
                if (staff.isEmpty) return const Card(child: ListTile(title: Text('No approved staff yet')));
                return Column(
                  children: staff.map((m) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified_user_outlined, color: Colors.green),
                      title: Text(m.name.isEmpty ? 'Railway Staff' : m.name),
                      subtitle: Text('${m.email}\n${m.phone.isEmpty ? 'No phone listed' : m.phone}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Send password reset email',
                        onPressed: m.email.isEmpty ? null : () => _resetPassword(m.email),
                        icon: const Icon(Icons.key_outlined),
                      ),
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
