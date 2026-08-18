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
    final email = (request['email'] ?? '').toString().trim().toLowerCase();
    if (requestId.isEmpty || email.isEmpty || _busyRequestIds.contains(requestId)) {
      return;
    }

    // Only the synchronous state update happens inside setState.
    // Firestore work is performed afterwards so Flutter never receives
    // an async callback from setState.
    setState(() => _busyRequestIds.add(requestId));

    try {
      await FirebaseFirestore.instance
          .collection('staff_requests')
          .doc(requestId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
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
        title: const Text(
          'RailSahayak Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ADMINISTRATOR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Staff approval requests',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Approve a staff member before they can use the Railway Staff login.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _requestsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Card(
                    child: ListTile(
                      title: const Text('Could not load staff requests'),
                      subtitle: Text('${snapshot.error}'),
                    ),
                  );
                }

                final requests = snapshot.data ?? [];
                if (requests.isEmpty) {
                  return const Card(
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('No pending staff requests'),
                    ),
                  );
                }

                return Column(
                  children: requests.map((request) {
                    final name = (request['name'] ?? 'Railway Staff').toString();
                    final email = (request['email'] ?? '').toString();
                    final phone = (request['phone'] ?? '').toString();
                    final id = (request['id'] ?? '').toString();
                    final busy = _busyRequestIds.contains(id);

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
                        title: Text(name),
                        subtitle: Text(
                          '$email\n${phone.isEmpty ? 'No phone listed' : phone}',
                        ),
                        isThreeLine: true,
                        trailing: busy
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Wrap(
                                children: [
                                  IconButton(
                                    tooltip: 'Approve',
                                    onPressed: () => _approveRequest(request),
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Reject',
                                    onPressed: () => _rejectRequest(id),
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      color: Colors.red,
                                    ),
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
            const Text(
              'Approved staff',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<UserProfile>>(
              future: _staffFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final staff = snapshot.data ?? [];
                if (staff.isEmpty) {
                  return const Card(
                    child: ListTile(title: Text('No approved staff yet')),
                  );
                }
                return Column(
                  children: staff.map((m) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.green,
                        ),
                        title: Text(
                          m.name.isEmpty ? 'Railway Staff' : m.name,
                        ),
                        subtitle: Text(
                          '${m.email}\n${m.phone.isEmpty ? 'No phone listed' : m.phone}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Send password reset email',
                          onPressed: m.email.isEmpty
                              ? null
                              : () => _resetPassword(m.email),
                          icon: const Icon(Icons.key_outlined),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 22),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Staff approval is stored in Firestore. Passwords are never stored in Firestore. Staff must authenticate with their approved company email.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
