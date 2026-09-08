import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/assistance_request.dart';
import '../../providers/request_provider.dart';
import '../../services/assistance_workflow_service.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  static const _blue = Color(0xFF303F9F);
  static const _surface = Color(0xFFFFF4EC);
  static const _background = Color(0xFFFFFBF8);
  final Set<String> _expandedRequests = <String>{};
  int _tabIndex = 0;

  List<AssistanceRequest> _byStatus(List<AssistanceRequest> requests, String status) =>
      requests.where((r) => r.status == status).toList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final currentStaff = provider.currentUser;
    final allRequests = provider.staffRequests;
    final staffName = currentStaff?.name.trim().isNotEmpty == true
        ? currentStaff!.name.trim()
        : 'Railway Staff';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(
          _tabIndex == 0
              ? 'Staff Support Console'
              : _tabIndex == 1
                  ? 'Assistance Requests'
                  : _tabIndex == 2
                      ? 'Station Duty'
                      : 'Staff Profile',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: provider.isLoading ? null : provider.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _home(context, staffName, allRequests),
          _requests(context, allRequests),
          _duty(context, staffName, allRequests),
          _profile(context, staffName),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.location_on_outlined), selectedIcon: Icon(Icons.location_on), label: 'Duty'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _home(BuildContext context, String staffName, List<AssistanceRequest> requests) {
    final requested = _byStatus(requests, 'Requested').length;
    final atStation = _byStatus(requests, 'At Station').length;
    final inProgress = requests.where((r) => {'Assigned', 'Located', 'Boarding', 'Boarded'}.contains(r.status)).length;
    final completed = _byStatus(requests, 'Completed').length;

    return RefreshIndicator(
      onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 250)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: _blue,
            padding: const EdgeInsets.fromLTRB(28, 6, 28, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Station Duty: $staffName',
                  style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Acknowledge, locate and board passengers who need assistance.',
                  style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.35),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("TODAY'S WORK", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: .8)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.45,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _statTile('Need assistance', requested, Icons.notifications_active, Colors.orange.shade800, () => _openRequests('Requested')),
                    _statTile('At station', atStation, Icons.location_on, Colors.deepOrange, () => _openRequests('At Station')),
                    _statTile('In progress', inProgress, Icons.directions_walk, _blue, () => _openRequests('In Progress')),
                    _statTile('Completed', completed, Icons.done_all, Colors.green.shade800, () => _openRequests('Completed')),
                  ],
                ),
                const SizedBox(height: 28),
                const Text('QUICK ACTIONS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: .8)),
                const SizedBox(height: 12),
                _quickTile(Icons.support_agent, 'View assistance requests', 'Handle passenger assistance workflow', () => setState(() => _tabIndex = 1)),
                _quickTile(Icons.location_on, 'Station duty', 'See your current station workload', () => setState(() => _tabIndex = 2)),
                _quickTile(Icons.person_pin_circle, 'Active passengers', 'Jump to requests assigned to staff', () => _openRequests('In Progress')),
                _quickTile(Icons.done_all, 'Completed assistance', 'Review completed requests', () => _openRequests('Completed')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String title, int count, IconData icon, Color iconColor, VoidCallback onTap) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 25),
              Text('$count', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(blurRadius: 5, offset: Offset(0, 2), color: Color(0x12000000))],
      ),
      child: ListTile(
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
        leading: Icon(icon, color: _blue, size: 28),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _requests(BuildContext context, List<AssistanceRequest> allRequests) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _requestFilterRow(allRequests),
        const SizedBox(height: 8),
        ..._filteredRequests(allRequests).map((req) => _requestCard(context, req)),
      ],
    );
  }

  String _requestFilter = 'All';

  List<AssistanceRequest> _filteredRequests(List<AssistanceRequest> requests) {
    switch (_requestFilter) {
      case 'Requested':
      case 'At Station':
      case 'Assigned':
      case 'Located':
      case 'Boarding':
      case 'Boarded':
      case 'Completed':
      case 'Escalated':
      case 'Cancelled':
        return requests.where((r) => r.status == _requestFilter).toList();
      case 'In Progress':
        return requests.where((r) => {'Assigned', 'Located', 'Boarding', 'Boarded'}.contains(r.status)).toList();
      default:
        return requests;
    }
  }

  Widget _requestFilterRow(List<AssistanceRequest> requests) {
    final items = [
      ('All', Icons.check),
      ('Requested', Icons.hourglass_empty),
      ('At Station', Icons.location_on),
      ('Assigned', Icons.assignment_ind_outlined),
      ('Located', Icons.person_pin_circle),
      ('Boarding', Icons.directions_walk),
      ('Boarded', Icons.check_circle_outline),
      ('Completed', Icons.done_all),
    ];
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: _requestFilter == item.$1,
                  onSelected: (_) => setState(() => _requestFilter = item.$1),
                  avatar: Icon(item.$2, size: 17),
                  label: Text(item.$1),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _requestCard(BuildContext context, AssistanceRequest req) {
    final expanded = _expandedRequests.contains(req.id);
    final statusData = _statusStyle(req.status);
    final terminal = {'Completed', 'Cancelled', 'Escalated'}.contains(req.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: statusData.color, width: req.status == 'At Station' ? 2 : 1.2),
        boxShadow: const [BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Color(0x18000000))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () => setState(() => expanded ? _expandedRequests.remove(req.id) : _expandedRequests.add(req.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 155),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(color: statusData.color, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusData.icon, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(req.status.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(req.passengerName.isEmpty ? 'Passenger' : req.passengerName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 5),
                Align(alignment: Alignment.centerRight, child: Text(req.trainNo.isEmpty ? 'Train' : req.trainNo, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600))),
                const SizedBox(height: 8),
                Text('${req.coach} • ${req.seat ?? 'Seat not specified'}  •  PNR ${req.pnr}', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (req.boardingStation.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text('Boarding: ${req.boardingStation}'),
                ],
                if (req.platform?.isNotEmpty == true || req.currentLocation?.isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text([
                    if (req.platform?.isNotEmpty == true) 'Platform ${req.platform}',
                    if (req.currentLocation?.isNotEmpty == true) req.currentLocation!,
                  ].join(' • '), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: expanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 22),
                            Wrap(spacing: 7, runSpacing: 6, children: req.assistanceType.map((x) => Chip(label: Text(x), visualDensity: VisualDensity.compact)).toList()),
                            if (req.notes?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text('Notes: ${req.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                            if (req.passengerPhone.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Passenger: ${req.passengerPhone}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                            if (req.status == 'Escalated') ...[
                              const SizedBox(height: 12),
                              const Text('Escalated to supervisor. Awaiting further action.', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.deepOrange)),
                            ] else if (!terminal) ...[
                              const SizedBox(height: 12),
                              _actionButton(context, req),
                              if (req.status == 'At Station' || req.status == 'Assigned') ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _escalate(context, req),
                                  icon: const Icon(Icons.warning_amber),
                                  label: const Text('Escalate to supervisor'),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.deepOrange, minimumSize: const Size(double.infinity, 44)),
                                ),
                              ],
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
                Text(expanded ? 'Tap to collapse' : 'Tap for request details', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, AssistanceRequest req) {
    String label;
    IconData icon;
    switch (req.status) {
      case 'At Station':
        label = 'Acknowledge Request';
        icon = Icons.notifications_active;
        break;
      case 'Assigned':
        label = 'Passenger Located';
        icon = Icons.person_pin_circle;
        break;
      case 'Located':
        label = 'Start Boarding';
        icon = Icons.directions_walk;
        break;
      case 'Boarding':
        label = 'Confirm Passenger Boarded';
        icon = Icons.check_circle;
        break;
      case 'Boarded':
        label = 'Complete Assistance';
        icon = Icons.done_all;
        break;
      default:
        label = 'Accept & Assign';
        icon = Icons.assignment_ind_outlined;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final next = switch (req.status) {
            'Requested' => 'Assigned',
            'At Station' => 'Assigned',
            'Assigned' => 'Located',
            'Located' => 'Boarding',
            'Boarding' => 'Boarded',
            'Boarded' => 'Completed',
            _ => null,
          };
          if (next == null) return;
          try {
            await AssistanceWorkflowService().updateStatus(req.id, next);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_successMessage(next)), backgroundColor: Colors.green));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update request: $e'), backgroundColor: Colors.red));
            }
          }
        },
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      ),
    );
  }

  Future<void> _escalate(BuildContext context, AssistanceRequest req) async {
    try {
      await AssistanceWorkflowService().escalate(req.id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supervisor escalation sent.'), backgroundColor: Colors.deepOrange));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not escalate: $e'), backgroundColor: Colors.red));
    }
  }

  String _successMessage(String status) => switch (status) {
        'Assigned' => 'Request acknowledged and assigned to you.',
        'Located' => 'Passenger marked as located.',
        'Boarding' => 'Boarding assistance started.',
        'Boarded' => 'Passenger marked as boarded.',
        'Completed' => 'Assistance completed.',
        _ => 'Request updated.',
      };

  void _openRequests(String filter) {
    setState(() {
      _requestFilter = filter;
      _tabIndex = 1;
    });
  }

  Widget _duty(BuildContext context, String staffName, List<AssistanceRequest> requests) {
    final active = requests.where((r) => !{'Completed', 'Cancelled'}.contains(r.status)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              const CircleAvatar(radius: 26, child: Icon(Icons.location_on)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(staffName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 4), const Text('Active station duty')])),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('ASSIGNED WORKLOAD', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: .8)),
        const SizedBox(height: 12),
        if (active.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(22), child: Center(child: Text('No active passenger assistance requests.'))))
        else
          ...active.map((req) => _compactDutyTile(req)),
      ],
    );
  }

  Widget _compactDutyTile(AssistanceRequest req) {
    final statusData = _statusStyle(req.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: CircleAvatar(backgroundColor: statusData.color, foregroundColor: Colors.white, child: Icon(statusData.icon, size: 19)),
        title: Text(req.passengerName.isEmpty ? 'Passenger' : req.passengerName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${req.trainNo} • ${req.coach} • ${req.seat ?? 'Seat N/A'}\n${req.status}'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() {
          _requestFilter = req.status;
          _tabIndex = 1;
          _expandedRequests.add(req.id);
        }),
      ),
    );
  }

  Widget _profile(BuildContext context, String staffName) {
    final provider = context.read<RequestProvider>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              const CircleAvatar(radius: 38, child: Icon(Icons.person, size: 40)),
              const SizedBox(height: 12),
              Text(staffName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Railway Staff'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.location_on), title: const Text('Station duty'), subtitle: const Text('Active')),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.logout), title: const Text('Sign out'), onTap: provider.logout),
            ],
          ),
        ),
      ],
    );
  }

  ({Color color, IconData icon}) _statusStyle(String status) {
    switch (status) {
      case 'At Station':
        return (color: const Color(0xFFE65100), icon: Icons.location_on);
      case 'Assigned':
        return (color: _blue, icon: Icons.assignment_ind_outlined);
      case 'Located':
        return (color: Colors.teal, icon: Icons.person_pin_circle);
      case 'Boarding':
        return (color: Colors.indigo, icon: Icons.directions_walk);
      case 'Boarded':
        return (color: Colors.green, icon: Icons.check_circle);
      case 'Completed':
        return (color: Colors.green.shade800, icon: Icons.done_all);
      case 'Cancelled':
        return (color: Colors.grey, icon: Icons.cancel_outlined);
      case 'Escalated':
        return (color: Colors.deepOrange, icon: Icons.warning_amber);
      default:
        return (color: Colors.orange.shade800, icon: Icons.hourglass_empty);
    }
  }
}
