import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/assistance_request.dart';
import '../../providers/request_provider.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final requests = provider.staffRequests;
    final currentStaff = provider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RailSahayak Staff'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: provider.isLoading ? null : provider.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.indigo.shade800,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.badge, color: Colors.white, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      currentStaff?.name.isNotEmpty == true
                          ? currentStaff!.name
                          : 'Railway Staff',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      currentStaff?.email ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Assistance Requests',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (requests.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No assistance requests at the moment.'),
                  ),
                ),
              )
            else
              ...requests.map((req) => _requestCard(context, req, currentStaff)),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(
    BuildContext context,
    AssistanceRequest req,
    dynamic currentStaff,
  ) {
    final provider = context.read<RequestProvider>();
    final isAssignedToMe = req.staffId == currentStaff?.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              req.passengerName.isEmpty ? 'Passenger' : req.passengerName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('Train: ${req.trainNo}'),
            Text('Coach: ${req.coach}'),
            Text('PNR: ${req.pnr}'),
            Text('Phone: ${req.passengerPhone}'),
            const SizedBox(height: 6),
            Text('Status: ${req.status}'),
            if (req.staffName != null && req.staffName!.isNotEmpty)
              Text(
                'Assigned to: ${req.staffName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            if (req.status != 'Completed' && req.status != 'Cancelled') ...[
              const Divider(height: 24),
              Row(
                children: [
                  if (req.status == 'Requested')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          provider.updateRequestStatus(req.id, 'Assigned');
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Accept Request'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (req.status == 'Assigned' && isAssignedToMe)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          provider.updateRequestStatus(req.id, 'Assisting');
                        },
                        icon: const Icon(Icons.directions_walk),
                        label: const Text('Start Assisting'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (req.status == 'Assisting' && isAssignedToMe)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          provider.updateRequestStatus(req.id, 'Completed');
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Passenger Boarded'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
