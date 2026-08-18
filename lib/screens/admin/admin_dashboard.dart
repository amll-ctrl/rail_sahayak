import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../providers/request_provider.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<RequestProvider>().logout();
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
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.refreshAdminData();
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Administrator',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user?.name.isNotEmpty == true ? user!.name : 'Admin',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(user?.email ?? ''),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Colors.indigo.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Admin controls',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade50,
                  child: Icon(
                    Icons.badge_outlined,
                    color: Colors.indigo.shade800,
                  ),
                ),
                title: const Text('Staff management'),
                subtitle: Text(
                  provider.adminStaffCandidates.isEmpty
                      ? 'No pending staff accounts.'
                      : '${provider.adminStaffCandidates.length} pending account(s)',
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...provider.adminStaffCandidates.map(
              (candidate) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    candidate.name.isNotEmpty ? candidate.name : candidate.email,
                  ),
                  subtitle: Text(
                    '${candidate.email}\n@${candidate.username}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Approve staff',
                        onPressed: () async {
                          await provider.approveStaff(candidate.id);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        color: Colors.green.shade700,
                      ),
                      IconButton(
                        tooltip: 'Reject account',
                        onPressed: () async {
                          await provider.rejectStaff(candidate.id);
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        color: Colors.red.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Requests overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Total requests: ${provider.staffRequests.length}'),
                    const SizedBox(height: 6),
                    const Text(
                      'Admin can monitor the same live Firestore request data used by railway staff.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
