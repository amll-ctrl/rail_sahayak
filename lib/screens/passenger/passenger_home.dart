import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../models/assistance_request.dart';
import '../../services/assistance_workflow_service.dart';
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
        actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: provider.isLoading ? null : provider.logout)],
      ),
      body: user == null
          ? const Center(child: Text('Authentication error. Please log in again.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _buildWelcomeCard(user),
                const SizedBox(height: 24),
                Row(children: [
                  const Expanded(child: Text('My Assistance Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestForm())), icon: const Icon(Icons.add), label: const Text('New Request'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))))
                ]),
                const SizedBox(height: 12),
                if (activeRequests.isEmpty)
                  _buildEmptyStateCard(context)
                else
                  ...activeRequests.map((req) => _buildRequestCard(context, req)),
              ]),
            ),
    );
  }

  Widget _buildWelcomeCard(user) => Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: [Colors.orange.shade800, Colors.orange.shade600], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome, ${user.name}!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Text('Phone: ${user.phone}  |  Role: Passenger', style: const TextStyle(fontSize: 14, color: Colors.white70)),
        if (user.disabilityType != null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(.2), borderRadius: BorderRadius.circular(8)), child: Text('Accessibility: ${user.disabilityType}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))
        ],
      ]),
    ),
  );

  Widget _buildEmptyStateCard(BuildContext context) => Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [
      Icon(Icons.wheelchair_pickup, size: 72, color: Colors.grey.shade400),
      const SizedBox(height: 16),
      const Text('No Boarding Assistance Requested', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      const Text('Request help before your journey and let railway staff know when you reach the station.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestForm())), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Request Assistance Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
    ])),
  );

  Widget _buildRequestCard(BuildContext context, AssistanceRequest req) {
    final terminal = req.status == 'Completed' || req.status == 'Cancelled';
    final canArrive = req.status == 'Requested' || req.status == 'Assigned';
    final statusColor = _statusColor(req.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: statusColor.withOpacity(.5), width: 1.5)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Chip(avatar: Icon(_statusIcon(req.status), color: Colors.white, size: 16), label: Text(req.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)), backgroundColor: statusColor)), const SizedBox(width: 8), Text('PNR: ${req.pnr}', style: const TextStyle(fontWeight: FontWeight.w800))]),
        const Divider(height: 20),
        Row(children: [const Icon(Icons.train, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text(req.trainNo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), Text('${req.coach} • ${req.seat ?? 'Seat'}', style: const TextStyle(fontWeight: FontWeight.bold))]),
        if (req.boardingStation.isNotEmpty) ...[const SizedBox(height: 8), Text('Boarding: ${req.boardingStation}', style: const TextStyle(color: Colors.black87))],
        if (req.platform?.isNotEmpty == true || req.currentLocation?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text([if (req.platform?.isNotEmpty == true) 'Platform ${req.platform}', if (req.currentLocation?.isNotEmpty == true) req.currentLocation!].join(' • '), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 18),
        _progress(req.status),
        if (req.staffName?.isNotEmpty == true) ...[const SizedBox(height: 12), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(Icons.person_pin, color: Colors.blue.shade800), const SizedBox(width: 8), Text('Staff: ${req.staffName}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900))]))],
        if (canArrive) ...[
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _markAtStation(context, req), icon: const Icon(Icons.location_on), label: const Text("I'M AT THE STATION / READY TO BOARD", style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        ],
        if (!terminal) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => _cancel(context, req), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size(double.infinity, 40)), child: const Text('Cancel Request', style: TextStyle(color: Colors.red))),
        ],
      ])),
    );
  }

  Widget _progress(String status) {
    const steps = ['Requested', 'At Station', 'Assigned', 'Located', 'Boarding', 'Boarded'];
    var current = steps.indexOf(status);
    if (status == 'Completed') current = steps.length - 1;
    if (current < 0) current = status == 'Cancelled' ? -1 : 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: List.generate(steps.length, (i) => Expanded(child: Row(children: [Expanded(child: Container(height: 5, decoration: BoxDecoration(color: i <= current ? Colors.green : Colors.grey.shade300, borderRadius: BorderRadius.circular(5)))), if (i < steps.length - 1) const SizedBox(width: 3)])))),
      const SizedBox(height: 8),
      Text(_friendlyStatus(status), style: const TextStyle(fontWeight: FontWeight.bold)),
    ]);
  }

  Future<void> _markAtStation(BuildContext context, AssistanceRequest req) async {
    final result = await showDialog<Map<String, String>>(context: context, builder: (context) {
      final platform = TextEditingController();
      final location = TextEditingController();
      return AlertDialog(
        title: const Text('You are at the station?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This will alert railway staff. You only need to do this once.'),
          const SizedBox(height: 16),
          TextField(controller: platform, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Platform (optional)', prefixIcon: Icon(Icons.train))),
          const SizedBox(height: 10),
          TextField(controller: location, decoration: const InputDecoration(labelText: 'Where are you? (optional)', hintText: 'Waiting hall, lift, gate...', prefixIcon: Icon(Icons.location_on_outlined))),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not yet')), ElevatedButton(onPressed: () => Navigator.pop(context, {'platform': platform.text, 'location': location.text}), child: const Text('Notify staff'))],
      );
    });
    if (result == null || !context.mounted) return;
    try {
      await AssistanceWorkflowService().markPassengerAtStation(requestId: req.id, platform: result['platform'], location: result['location']);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff have been notified. Please remain where you are.'), backgroundColor: Colors.green));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not notify staff: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _cancel(BuildContext context, AssistanceRequest req) async {
    try {
      await AssistanceWorkflowService().updateStatus(req.id, 'Cancelled');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not cancel request: $e'), backgroundColor: Colors.red));
    }
  }

  Color _statusColor(String status) {
    switch (status) { case 'At Station': return Colors.deepOrange; case 'Assigned': return Colors.blue.shade700; case 'Located': return Colors.teal; case 'Boarding': return Colors.indigo; case 'Boarded': case 'Completed': return Colors.green.shade700; case 'Cancelled': return Colors.grey; default: return Colors.orange.shade800; }
  }
  IconData _statusIcon(String status) { switch (status) { case 'At Station': return Icons.location_on; case 'Assigned': return Icons.assignment_ind; case 'Located': return Icons.person_pin_circle; case 'Boarding': return Icons.directions_walk; case 'Boarded': case 'Completed': return Icons.check_circle; case 'Cancelled': return Icons.cancel; default: return Icons.hourglass_empty; } }
  String _friendlyStatus(String status) { switch (status) { case 'At Station': return 'Staff are being notified'; case 'Assigned': return 'Staff member assigned'; case 'Located': return 'Staff member has found you'; case 'Boarding': return 'Boarding assistance in progress'; case 'Boarded': case 'Completed': return 'You are on board'; default: return 'Request confirmed'; } }
}
