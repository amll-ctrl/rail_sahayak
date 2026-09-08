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
  static const _background = Color(0xFFFFFBF8);
  static const _surface = Color(0xFFFFF4EC);
  static const _muted = Color(0xFF6B625D);

  final Set<String> _expanded = <String>{};
  final TextEditingController _searchController = TextEditingController();

  int _tabIndex = 0;
  String _filter = 'All';
  String _sort = 'Priority';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final requests = provider.staffRequests;
    final user = provider.currentUser;
    final staffName = user?.name.trim().isNotEmpty == true ? user!.name.trim() : 'Railway Staff';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
          _home(staffName, requests),
          _requests(requests),
          _duty(requests),
          _profile(user, staffName),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (value) => setState(() => _tabIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.location_on_outlined), selectedIcon: Icon(Icons.location_on), label: 'Duty'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  String get _title => switch (_tabIndex) {
        0 => 'Staff Support Console',
        1 => 'Assistance Requests',
        2 => 'Station Duty',
        _ => 'Staff Profile',
      };

  Widget _home(String staffName, List<AssistanceRequest> requests) {
    final requested = _count(requests, 'Requested');
    final atStation = _count(requests, 'At Station');
    final inProgress = requests.where((r) => _activeStatuses.contains(r.status)).length;
    final completed = _count(requests, 'Completed');
    final attention = requested + atStation;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        children: [
          Container(
            color: _blue,
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Station Duty: $staffName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Handle assistance requests quickly and keep passengers moving.',
                  style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.35),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('TODAY\'S WORK'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _statTile('Need assistance', requested, Icons.notifications_none, Colors.orange.shade800, () => _openRequests('Requested')),
                    _statTile('At station', atStation, Icons.location_on_outlined, Colors.deepOrange, () => _openRequests('At Station')),
                    _statTile('In progress', inProgress, Icons.directions_walk_outlined, _blue, () => _openRequests('In Progress')),
                    _statTile('Completed', completed, Icons.done_all, Colors.green.shade800, () => _openRequests('Completed')),
                  ],
                ),
                const SizedBox(height: 24),
                _attentionBanner(attention),
                const SizedBox(height: 24),
                const _SectionLabel('QUICK ACTIONS'),
                const SizedBox(height: 10),
                _actionTile(Icons.support_agent_outlined, 'Requests', 'View and process passenger requests', () => setState(() => _tabIndex = 1)),
                _actionTile(Icons.location_on_outlined, 'Station duty', 'See passengers by boarding station', () => setState(() => _tabIndex = 2)),
                _actionTile(Icons.priority_high, 'Needs attention', 'Show new and waiting requests', () => _openRequests('Attention')),
                _actionTile(Icons.done_all, 'Completed', 'Review completed assistance', () => _openRequests('Completed')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attentionBanner(int count) {
    return Material(
      color: count > 0 ? const Color(0xFFFFF0DF) : const Color(0xFFEAF5EC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: count > 0 ? () => _openRequests('Attention') : null,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Icon(count > 0 ? Icons.priority_high : Icons.check_circle_outline, color: count > 0 ? Colors.deepOrange : Colors.green.shade800),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  count > 0 ? '$count request${count == 1 ? '' : 's'} need attention' : 'No requests need attention',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (count > 0) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(String title, int count, IconData icon, Color iconColor, VoidCallback onTap) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const Spacer(),
              Text('$count', style: const TextStyle(fontSize: 30, height: 1, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
        leading: Icon(icon, color: _blue, size: 27),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _requests(List<AssistanceRequest> requests) {
    final filtered = _visibleRequests(requests);
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search passenger, train, PNR or station',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() {}); }),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _compactControl(Icons.filter_list, _filter, _showFilterSheet)),
              const SizedBox(width: 8),
              Expanded(child: _compactControl(Icons.sort, _sort, _showSortSheet)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${filtered.length} request${filtered.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_filter != 'All') TextButton(onPressed: () => setState(() => _filter = 'All'), child: const Text('Clear filter')),
            ],
          ),
          const SizedBox(height: 2),
          if (filtered.isEmpty) _emptyState(),
          ...filtered.map((req) => _requestCard(req)),
        ],
      ),
    );
  }

  Widget _compactControl(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: Colors.black87,
        side: const BorderSide(color: Color(0xFFD8CEC7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18)),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 42, color: _muted),
          SizedBox(height: 10),
          Text('No matching requests', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          SizedBox(height: 4),
          Text('Try another filter or search term.', textAlign: TextAlign.center, style: TextStyle(color: _muted)),
        ],
      ),
    );
  }

  List<AssistanceRequest> _visibleRequests(List<AssistanceRequest> source) {
    final query = _searchController.text.trim().toLowerCase();
    Iterable<AssistanceRequest> result = source;

    if (_filter == 'Attention') {
      result = result.where((r) => r.status == 'Requested' || r.status == 'At Station');
    } else if (_filter == 'In Progress') {
      result = result.where((r) => _activeStatuses.contains(r.status));
    } else if (_filter != 'All') {
      result = result.where((r) => r.status == _filter);
    }

    if (query.isNotEmpty) {
      result = result.where((r) {
        final haystack = [r.passengerName, r.trainNo, r.pnr, r.coach, r.seat?.toString() ?? '', r.boardingStation, r.currentLocation ?? ''].join(' ').toLowerCase();
        return haystack.contains(query);
      });
    }

    final list = result.toList();
    if (_sort == 'Priority') {
      list.sort((a, b) => _priority(a.status).compareTo(_priority(b.status)));
    } else if (_sort == 'Passenger') {
      list.sort((a, b) => a.passengerName.toLowerCase().compareTo(b.passengerName.toLowerCase()));
    } else if (_sort == 'Train') {
      list.sort((a, b) => a.trainNo.compareTo(b.trainNo));
    }
    return list;
  }

  int _priority(String status) => switch (status) {
        'Requested' => 0,
        'At Station' => 1,
        'Assigned' => 2,
        'Located' => 3,
        'Boarding' => 4,
        'Boarded' => 5,
        'Escalated' => 6,
        'Completed' => 7,
        'Cancelled' => 8,
        _ => 9,
      };

  Widget _requestCard(AssistanceRequest req) {
    final expanded = _expanded.contains(req.id);
    final status = _statusStyle(req.status);
    final terminal = {'Completed', 'Cancelled', 'Escalated'}.contains(req.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: status.color, width: req.status == 'At Station' ? 1.8 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => setState(() => expanded ? _expanded.remove(req.id) : _expanded.add(req.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(color: status.color, borderRadius: BorderRadius.circular(9)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(status.icon, color: Colors.white, size: 15),
                            const SizedBox(width: 5),
                            Flexible(child: Text(req.status.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(req.passengerName.isEmpty ? 'Passenger' : req.passengerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                    Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 21, color: _muted),
                  ],
                ),
                const SizedBox(height: 7),
                Text(req.trainNo.isEmpty ? 'Train not specified' : req.trainNo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('${req.coach} • ${req.seat ?? 'Seat not specified'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (req.boardingStation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Boarding: ${req.boardingStation}', maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (req.platform?.isNotEmpty == true || req.currentLocation?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text([
                    if (req.platform?.isNotEmpty == true) 'Platform ${req.platform}',
                    if (req.currentLocation?.isNotEmpty == true) req.currentLocation!,
                  ].join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: expanded ? _requestDetails(req, terminal) : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _requestDetails(AssistanceRequest req, bool terminal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        Text('PNR  ${req.pnr}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: req.assistanceType.map((x) => Chip(label: Text(x), visualDensity: VisualDensity.compact)).toList(),
        ),
        if (req.notes?.isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Text('Notes: ${req.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
        if (req.passengerPhone.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Passenger: ${req.passengerPhone}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
        if (req.status == 'Escalated') ...[
          const SizedBox(height: 10),
          const Text('Escalated to supervisor.', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w700)),
        ] else if (!terminal) ...[
          const SizedBox(height: 10),
          _actionButton(req),
          if (req.status == 'At Station' || req.status == 'Assigned') ...[
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _escalate(req),
                icon: const Icon(Icons.warning_amber_outlined, size: 18),
                label: const Text('Escalate'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.deepOrange),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _actionButton(AssistanceRequest req) {
    final data = _nextAction(req.status);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _advance(req),
        icon: Icon(data.icon),
        label: Text(data.label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  ({String label, IconData icon, String? next}) _nextAction(String status) => switch (status) {
        'At Station' => (label: 'Acknowledge & Assign', icon: Icons.assignment_ind_outlined, next: 'Assigned'),
        'Assigned' => (label: 'Mark Passenger Located', icon: Icons.person_pin_circle_outlined, next: 'Located'),
        'Located' => (label: 'Start Boarding', icon: Icons.directions_walk_outlined, next: 'Boarding'),
        'Boarding' => (label: 'Confirm Passenger Boarded', icon: Icons.check_circle_outline, next: 'Boarded'),
        'Boarded' => (label: 'Complete Assistance', icon: Icons.done_all, next: 'Completed'),
        _ => (label: 'Accept & Assign', icon: Icons.assignment_ind_outlined, next: 'Assigned'),
      };

  Future<void> _advance(AssistanceRequest req) async {
    final next = _nextAction(req.status).next;
    if (next == null) return;
    try {
      await AssistanceWorkflowService().updateStatus(req.id, next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_success(next))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update request: $e')));
    }
  }

  Future<void> _escalate(AssistanceRequest req) async {
    try {
      await AssistanceWorkflowService().escalate(req.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supervisor escalation sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not escalate: $e')));
    }
  }

  String _success(String status) => switch (status) {
        'Assigned' => 'Request assigned to you.',
        'Located' => 'Passenger marked as located.',
        'Boarding' => 'Boarding assistance started.',
        'Boarded' => 'Passenger marked as boarded.',
        'Completed' => 'Assistance completed.',
        _ => 'Request updated.',
      };

  Widget _duty(List<AssistanceRequest> requests) {
    final active = requests.where((r) => _activeStatuses.contains(r.status) || r.status == 'At Station' || r.status == 'Requested').toList();
    final groups = <String, List<AssistanceRequest>>{};
    for (final req in active) {
      final station = req.boardingStation.trim().isEmpty ? 'Station not specified' : req.boardingStation.trim();
      groups.putIfAbsent(station, () => []).add(req);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Current workload', style: TextStyle(color: Colors.white70)),
                Text('${active.length} active passenger${active.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ])),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionLabel('BOARDING STATIONS'),
        const SizedBox(height: 10),
        if (groups.isEmpty) _emptyState(),
        ...groups.entries.map((entry) => _stationTile(entry.key, entry.value)),
      ],
    );
  }

  Widget _stationTile(String station, List<AssistanceRequest> requests) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () {
          _searchController.text = station;
          setState(() { _filter = 'All'; _tabIndex = 1; });
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        leading: const Icon(Icons.place_outlined, color: _blue),
        title: Text(station, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${requests.length} active request${requests.length == 1 ? '' : 's'}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _profile(dynamic user, String staffName) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        CircleAvatar(radius: 36, backgroundColor: _surface, child: Icon(Icons.person, size: 38, color: _blue)),
        const SizedBox(height: 12),
        Center(child: Text(staffName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
        const SizedBox(height: 24),
        _profileRow(Icons.badge_outlined, 'Username', user?.username),
        _profileRow(Icons.email_outlined, 'Email', user?.email),
        _profileRow(Icons.phone_outlined, 'Phone', user?.phone),
        _profileRow(Icons.security_outlined, 'Role', user?.role.toString().split('.').last),
        const SizedBox(height: 18),
        const Text('STAFF WORKFLOW', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .7)),
        const SizedBox(height: 8),
        const Text('Use Requests to acknowledge, locate, board and complete passenger assistance. Station Duty groups active passengers by boarding station.', style: TextStyle(color: _muted, height: 1.4)),
      ],
    );
  }

  Widget _profileRow(IconData icon, String label, String? value) {
    final text = value?.trim().isNotEmpty == true ? value!.trim() : 'Not provided';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [Icon(icon, color: _blue, size: 22), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: _muted)), const SizedBox(height: 2), Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))]))]),
    );
  }

  Future<void> _showFilterSheet() async {
    final options = ['All', 'Attention', 'Requested', 'At Station', 'In Progress', 'Assigned', 'Located', 'Boarding', 'Boarded', 'Completed', 'Escalated', 'Cancelled'];
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: options.map((option) => RadioListTile<String>(value: option, groupValue: _filter, title: Text(option), onChanged: (value) => Navigator.pop(context, value))).toList(),
        ),
      ),
    );
    if (value != null) setState(() => _filter = value);
  }

  Future<void> _showSortSheet() async {
    final options = ['Priority', 'Passenger', 'Train'];
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: options.map((option) => RadioListTile<String>(value: option, groupValue: _sort, title: Text(option), onChanged: (value) => Navigator.pop(context, value))).toList()),
      ),
    );
    if (value != null) setState(() => _sort = value);
  }

  void _openRequests(String filter) {
    setState(() {
      _filter = filter;
      _tabIndex = 1;
      _searchController.clear();
    });
  }

  int _count(List<AssistanceRequest> requests, String status) => requests.where((r) => r.status == status).length;

  static const _activeStatuses = {'Assigned', 'Located', 'Boarding', 'Boarded'};

  ({Color color, IconData icon}) _statusStyle(String status) => switch (status) {
        'Requested' => (color: Colors.orange.shade800, icon: Icons.hourglass_empty),
        'At Station' => (color: Colors.deepOrange, icon: Icons.location_on),
        'Assigned' => (color: _blue, icon: Icons.assignment_ind_outlined),
        'Located' => (color: Colors.teal, icon: Icons.person_pin_circle_outlined),
        'Boarding' => (color: Colors.indigo, icon: Icons.directions_walk_outlined),
        'Boarded' => (color: Colors.green, icon: Icons.check_circle_outline),
        'Completed' => (color: Colors.green.shade800, icon: Icons.done_all),
        'Escalated' => (color: Colors.deepOrange, icon: Icons.warning_amber_outlined),
        'Cancelled' => (color: Colors.grey, icon: Icons.cancel_outlined),
        _ => (color: Colors.grey, icon: Icons.help_outline),
      };
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .8));
}
