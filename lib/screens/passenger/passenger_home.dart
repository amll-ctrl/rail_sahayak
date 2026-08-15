import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../models/assistance_request.dart';
import 'request_form.dart';

class PassengerHome extends StatelessWidget {
  const PassengerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final user = provider.currentUser;
    final activeRequests = provider.passengerRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RailSahayak Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              provider.logout();
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Authentication error. Please log in again.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome Card with User details
                  _buildWelcomeCard(context, user),
                  const SizedBox(height: 24),

                  // Active Request Heading
                  Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    const Expanded(
      child: Text(
        'My Assistance Requests',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ),
    const SizedBox(width: 8),
    if (activeRequests.isEmpty)
      ElevatedButton.icon(
        onPressed: () => _navigateToRequestForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
      ),
  ],
),
                  const SizedBox(height: 12),

                  // Requests List
                  if (activeRequests.isEmpty)
                    _buildEmptyStateCard(context)
                  else
                    ...activeRequests.map((req) => _buildRequestCard(context, req, provider)),
                ],
              ),
            ),
    );
  }

  void _navigateToRequestForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RequestForm()),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, user) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.orange.shade800, Colors.orange.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user.name}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Phone: ${user.phone}  |  Role: Passenger',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            if (user.disabilityType != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Accessibility: ${user.disabilityType}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.wheelchair_pickup, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Boarding Assistance Requested',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Do you need wheelchair assistance, guiding guide support, or luggage porter assistance? Request help now.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _navigateToRequestForm(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Request Assistance Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, AssistanceRequest req, RequestProvider provider) {
    // Accessibility color maps for statuses
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.hourglass_empty;
    
    if (req.status == 'Assigned') {
      statusColor = Colors.blue.shade700;
      statusIcon = Icons.assignment_ind;
    } else if (req.status == 'Assisting') {
      statusColor = Colors.amber.shade900;
      statusIcon = Icons.directions_walk;
    } else if (req.status == 'Completed') {
      statusColor = Colors.green.shade700;
      statusIcon = Icons.check_circle;
    } else if (req.status == 'Cancelled') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    final isNotInteractable = req.status == 'Completed' || req.status == 'Cancelled';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  avatar: Icon(statusIcon, color: Colors.white, size: 16),
                  label: Text(
                    req.status.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  backgroundColor: statusColor,
                ),
                Text(
                  'PNR: ${req.pnr}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 20),
            
            // Train & Coach Info
            Row(
  children: [
    const Icon(Icons.train, color: Colors.grey),
    const SizedBox(width: 8),
    Flexible(
      child: Text(
        'Train: ${req.trainNo}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ),
    const SizedBox(width: 16),
    const Icon(Icons.door_sliding, color: Colors.grey),
    const SizedBox(width: 8),
    Flexible(
      child: Text(
        'Coach: ${req.coach}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
),
            const SizedBox(height: 12),
            
            // Assistance items
            const Text(
              'Required Assistance:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: req.assistanceType.map((type) => Chip(
                label: Text(type, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.grey.shade200,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
            
            if (req.notes != null && req.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Notes: ${req.notes}',
                style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF212121)),
              ),
            ],

            if (req.staffName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_pin, color: Colors.blue.shade800),
                    const SizedBox(width: 8),
                    Text(
                      'Assigned Staff: ${req.staffName}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Large Accessibility Panic/Ready Check-in Alert button
            if (!isNotInteractable) ...[
              ElevatedButton.icon(
                onPressed: req.status == 'Assisting' ? null : () async {
                  await provider.updateRequestStatus(req.id, 'Assisting');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Alert Sent! Staff notified that you are at the station.'),
                        backgroundColor: Colors.blueAccent,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.spatial_audio_off, color: Colors.white),
                label: const Text(
                  'I AM AT THE STATION / READY TO BOARD',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Cancel assistance trigger
              OutlinedButton(
                onPressed: () {
                  provider.updateRequestStatus(req.id, 'Cancelled');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text('Cancel Request', style: TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
