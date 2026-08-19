import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/request_provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const _red = Color(0xFFC62828);
  static const _deepRed = Color(0xFF8E0000);
  static const _surface = Color(0xFFFFF4EC);
  final _db = FirebaseFirestore.instance;
  final Set<String> _busy = <String>{};
  Future<_AdminData>? _dataFuture;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_AdminData> _loadData() async {
    final results = await Future.wait([
      _db.collection('users').get(),
      _db.collection('staff_requests').get(),
      _db.collection('requests').get(),
    ]);
    final users = (results[0] as QuerySnapshot<Map<String, dynamic>>).docs
        .map((d) => {'id': d.id, ...d.data()}).toList();
    final staffRequests = (results[1] as QuerySnapshot<Map<String, dynamic>>).docs
        .map((d) => {'id': d.id, ...d.data()}).toList();
    final requests = (results[2] as QuerySnapshot<Map<String, dynamic>>).docs
        .map((d) => {'id': d.id, ...d.data()}).toList();
    return _AdminData(users: users, staffRequests: staffRequests, requests: requests);
  }

  Future<void> _refresh() async {
    final future = _loadData();
    setState(() => _dataFuture = future);
    await future;
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await action();
      if (mounted) await _refresh();
    } catch (e) {
      if (mounted) _message('Action failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? _red : null),
    );
  }

  Future<void> _approveStaff(Map<String, dynamic> request) async {
    final requestId = '${request['id'] ?? ''}';
    final uid = '${request['uid'] ?? ''}'.trim();
    final email = '${request['email'] ?? ''}'.trim().toLowerCase();
    if (requestId.isEmpty || uid.isEmpty || email.isEmpty) {
      _message('This staff request is missing account information.', error: true);
      return;
    }
    await _run('approve:$requestId', () async {
      await _db.runTransaction((tx) async {
        tx.set(_db.collection('users').doc(uid), {
          'id': uid,
          'name': '${request['name'] ?? 'Railway Staff'}',
          'username': '${request['username'] ?? email.split('@').first}'.toLowerCase(),
          'email': email,
          'phone': '${request['phone'] ?? ''}',
          'role': 'staff',
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        tx.update(_db.collection('staff_requests').doc(requestId), {
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
        });
      });
      if (mounted) _message('$email approved as railway staff.');
    });
  }

  Future<void> _rejectStaff(String id) async {
    await _run('reject:$id', () async {
      await _db.collection('staff_requests').doc(id).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _message('Staff request rejected.');
    });
  }

  Future<void> _setStaffStatus(Map<String, dynamic> staff, bool active) async {
    final id = '${staff['id']}';
    await _run('staff:$id', () async {
      await _db.collection('users').doc(id).set({
        'status': active ? 'approved' : 'disabled',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) _message(active ? 'Staff access restored.' : 'Staff access disabled.');
    });
  }

  Future<void> _resetPassword(String email) async {
    if (email.trim().isEmpty) return;
    await _run('reset:$email', () async {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      if (mounted) _message('Password reset email sent to $email');
    });
  }

  Future<void> _updateRequestStatus(Map<String, dynamic> request, String status) async {
    final id = '${request['id']}';
    await _run('request:$id', () async {
      await _db.collection('requests').doc(id).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _message('Request marked as $status.');
    });
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

  void _showUsers(_AdminData data) {
    final passengers = data.users.where((u) => '${u['role']}'.toLowerCase() == 'passenger').toList();
    _showListSheet(
      title: 'Passenger management',
      items: passengers,
      empty: 'No passengers found.',
      builder: (u) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text('${u['name'] ?? 'Passenger'}'),
        subtitle: Text('${u['email'] ?? ''}\n${u['phone'] ?? 'No phone'}'),
        isThreeLine: true,
      ),
    );
  }

  void _showStaff(_AdminData data) {
    final staff = data.users.where((u) => '${u['role']}'.toLowerCase() == 'staff').toList();
    _showListSheet(
      title: 'Staff management',
      items: staff,
      empty: 'No approved staff yet.',
      builder: (s) {
        final disabled = '${s['status']}'.toLowerCase() == 'disabled';
        final id = '${s['id']}';
        return Card(color: _surface, child: ListTile(
          leading: Icon(disabled ? Icons.person_off_outlined : Icons.badge_outlined, color: _red),
          title: Text('${s['name'] ?? 'Railway Staff'}'),
          subtitle: Text('${s['email'] ?? ''}\n${disabled ? 'Access disabled' : 'Approved staff'}'),
          isThreeLine: true,
          trailing: Wrap(children: [
            IconButton(tooltip: 'Password reset', onPressed: _busy.contains('reset:${s['email']}') ? null : () => _resetPassword('${s['email'] ?? ''}'), icon: const Icon(Icons.key_outlined, color: _red)),
            IconButton(tooltip: disabled ? 'Enable staff' : 'Disable staff', onPressed: _busy.contains('staff:$id') ? null : () => _setStaffStatus(s, disabled), icon: Icon(disabled ? Icons.person_add_alt_1 : Icons.block, color: _red)),
          ]),
        ));
      },
    );
  }

  void _showRequests(_AdminData data) {
    _showListSheet(
      title: 'Assistance requests',
      items: data.requests,
      empty: 'No assistance requests found.',
      builder: (r) {
        final status = '${r['status'] ?? 'Requested'}';
        final id = '${r['id']}';
        return Card(color: _surface, child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['passengerName'] ?? 'Passenger'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Train ${r['trainNo'] ?? '-'} • Coach ${r['coach'] ?? '-'}\nPNR: ${r['pnr'] ?? '-'}\nStatus: $status'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              OutlinedButton(onPressed: _busy.contains('request:$id') ? null : () => _updateRequestStatus(r, 'Requested'), child: const Text('Requested')),
              OutlinedButton(onPressed: _busy.contains('request:$id') ? null : () => _updateRequestStatus(r, 'Completed'), child: const Text('Complete')),
              TextButton(onPressed: _busy.contains('request:$id') ? null : () => _updateRequestStatus(r, 'Cancelled'), child: const Text('Cancel', style: TextStyle(color: _red))),
            ]),
          ]),
        ));
      },
    );
  }

  void _showListSheet({required String title, required List<Map<String, dynamic>> items, required String empty, required Widget Function(Map<String, dynamic>) builder}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(child: SizedBox(
        height: MediaQuery.of(context).size.height * .82,
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 18, 12, 10), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))])),
          const Divider(height: 1),
          Expanded(child: items.isEmpty ? Center(child: Text(empty)) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: items.length, itemBuilder: (_, i) => builder(items[i]))),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<RequestProvider>().currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: _red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loggingOut ? null : _refresh, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Sign out', onPressed: _loggingOut ? null : _logout, icon: _loggingOut ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        color: _red,
        onRefresh: _refresh,
        child: FutureBuilder<_AdminData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _red));
            if (snapshot.hasError) return ListView(children: [const SizedBox(height: 120), Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load the dashboard.\n${snapshot.error}', textAlign: TextAlign.center))), Center(child: ElevatedButton(onPressed: _refresh, child: const Text('Try again')))]);
            final data = snapshot.data!;
            final users = data.users.where((u) => '${u['role']}'.toLowerCase() == 'passenger').length;
            final staff = data.users.where((u) => '${u['role']}'.toLowerCase() == 'staff').length;
            final pendingStaff = data.staffRequests.where((r) => '${r['status']}'.toLowerCase() == 'pending').toList();
            final active = data.requests.where((r) { final s = '${r['status']}'.toLowerCase(); return s == 'assigned' || s == 'assisting'; }).length;
            final requested = data.requests.where((r) => '${r['status']}'.toLowerCase() == 'requested').length;
            final completed = data.requests.where((r) => '${r['status']}'.toLowerCase() == 'completed').length;
            return ListView(padding: const EdgeInsets.all(20), children: [
              Card(color: _red, child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [const CircleAvatar(radius: 26, backgroundColor: Colors.white24, child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 30)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(admin?.name.isNotEmpty == true ? admin!.name : 'Administrator', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)), Text(admin?.email ?? '', style: const TextStyle(color: Colors.white70))]))]))),
              const SizedBox(height: 24),
              const Text('Overview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4), const Text('Live RailSahayak system statistics', style: TextStyle(color: Colors.grey)), const SizedBox(height: 18),
              GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.25, children: [
                _statCard(Icons.people, users, 'Total Users', Colors.blue, () => _showUsers(data)),
                _statCard(Icons.badge, staff, 'Staff', _deepRed, () => _showStaff(data)),
                _statCard(Icons.hourglass_top, requested, 'Requested', Colors.orange, () => _showRequests(data)),
                _statCard(Icons.directions_walk, active, 'Active', Colors.blue, () => _showRequests(data)),
                _statCard(Icons.check_circle, completed, 'Completed', Colors.green, () => _showRequests(data)),
                _statCard(Icons.pending_actions, pendingStaff.length, 'Staff Pending', _red, () => _showApprovals(pendingStaff)),
              ]),
              const SizedBox(height: 30), const Text('Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 14),
              _managementCard(Icons.people_alt_outlined, 'Passenger Management', 'View registered passengers', () => _showUsers(data)),
              _managementCard(Icons.badge_outlined, 'Staff Management', 'Enable, disable or reset staff access', () => _showStaff(data)),
              _managementCard(Icons.accessibility_new, 'Assistance Requests', 'Review and update request status', () => _showRequests(data)),
              _managementCard(Icons.how_to_reg_outlined, 'Staff Approval Requests', 'Approve or reject pending staff', () => _showApprovals(pendingStaff)),
              const SizedBox(height: 20),
            ]);
          },
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, int value, String label, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Card(color: _surface, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color, size: 30), Text('$value', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16))]))),
  );

  Widget _managementCard(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(
    color: _surface,
    child: ListTile(leading: Icon(icon, color: _red, size: 30), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right, color: _red), onTap: onTap),
  );

  void _showApprovals(List<Map<String, dynamic>> pending) {
    _showListSheet(
      title: 'Staff approval requests',
      items: pending,
      empty: 'No pending staff requests.',
      builder: (r) {
        final id = '${r['id']}';
        final busy = _busy.contains('approve:$id') || _busy.contains('reject:$id');
        return Card(color: _surface, child: ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFFFFE2DD), child: Icon(Icons.badge_outlined, color: _red)),
          title: Text('${r['name'] ?? 'Railway Staff'}'),
          subtitle: Text('${r['email'] ?? ''}\n${r['phone'] ?? 'No phone listed'}'),
          isThreeLine: true,
          trailing: busy ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: _red)) : Wrap(children: [
            IconButton(tooltip: 'Approve', onPressed: () => _approveStaff(r), icon: const Icon(Icons.check_circle_outline, color: Colors.green)),
            IconButton(tooltip: 'Reject', onPressed: () => _rejectStaff(id), icon: const Icon(Icons.cancel_outlined, color: _red)),
          ]),
        ));
      },
    );
  }
}

class _AdminData {
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> staffRequests;
  final List<Map<String, dynamic>> requests;
  const _AdminData({required this.users, required this.staffRequests, required this.requests});
}
