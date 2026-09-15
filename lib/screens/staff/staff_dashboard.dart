import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/assistance_request.dart';
import '../../providers/request_provider.dart';
import '../../services/assistance_workflow_service.dart';

class StaffDashboard extends StatefulWidget {
  final int initialTab;
  final String initialFilter;
  final String? initialExpandedId;

  const StaffDashboard({
    super.key,
    this.initialTab = 0,
    this.initialFilter = 'All',
    this.initialExpandedId,
  });

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

  late int _tabIndex;
  late String _filter;
  String _sort = 'Priority';

  static const _activeStatuses = {'Assigned', 'Located', 'Boarding', 'Boarded'};
  static const _terminalStatuses = {'Completed', 'Cancelled', 'Escalated'};

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab.clamp(0, 3);
    _filter = widget.initialFilter;
    if (widget.initialExpandedId != null) {
      _expanded.add(widget.initialExpandedId!);
    }
  }

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
    final staffName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'Railway Staff';

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
        onDestinationSelected: _navigateToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: 'Duty',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
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

  void _navigateToTab(int index) {
    if (index == _tabIndex) return;

    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    final route = MaterialPageRoute<void>(
      builder: (_) => StaffDashboard(initialTab: index),
    );

    if (_tabIndex == 0) {
      Navigator.of(context).push(route);
    } else {
      Navigator.of(context).pushReplacement(route);
    }
  }

  Widget _home(String staffName, List<AssistanceRequest> requests) {
    final requested = _count(requests, 'Requested');
    final atStation = _count(requests, 'At Station');
    final inProgress = requests
        .where((r) => _activeStatuses.contains(r.status))
        .length;
    final completed = _count(requests, 'Completed');
    final attention = requested + atStation;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Handle assistance requests quickly and keep passengers moving.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel("TODAY'S WORK"),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 116,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _statTile(
                      'Need assistance',
                      requested,
                      Icons.notifications_none,
                      Colors.orange.shade800,
                      () => _openRequests('Requested'),
                    ),
                    _statTile(
                      'At station',
                      atStation,
                      Icons.location_on_outlined,
                      Colors.deepOrange,
                      () => _openRequests('At Station'),
                    ),
                    _statTile(
                      'In progress',
                      inProgress,
                      Icons.directions_walk_outlined,
                      _blue,
                      () => _openRequests('In Progress'),
                    ),
                    _statTile(
                      'Completed',
                      completed,
                      Icons.done_all,
                      Colors.green.shade800,
                      () => _openRequests('Completed'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _attentionBanner(attention),
                const SizedBox(height: 24),
                const _SectionLabel('QUICK ACTIONS'),
                const SizedBox(height: 10),
                _actionTile(
                  Icons.support_agent_outlined,
                  'Requests',
                  'View and process passenger requests',
                  () => _openRequests('All'),
                ),
                _actionTile(
                  Icons.location_on_outlined,
                  'Station duty',
                  'See passengers by boarding station',
                  () => _navigateToTab(2),
                ),
                _actionTile(
                  Icons.priority_high,
                  'Needs attention',
                  'Show new and waiting requests',
                  () => _openRequests('Attention'),
                ),
                _actionTile(
                  Icons.done_all,
                  'Completed',
                  'Review completed assistance',
                  () => _openRequests('Completed'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attentionBanner(int count) {
    final active = count > 0;
    return Material(
      color: active
          ? const Color(0xFFFFF0DF)
          : const Color(0xFFEAF5EC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: active ? () => _openRequests('Attention') : null,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Icon(
                active
                    ? Icons.priority_high
                    : Icons.check_circle_outline,
                color: active
                    ? Colors.deepOrange
                    : Colors.green.shade800,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  active
                      ? '$count request${count == 1 ? '' : 's'} need attention'
                      : 'No requests need attention',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (active) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(
    String title,
    int count,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 25),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 3,
        ),
        leading: Icon(icon, color: _blue, size: 27),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _compactControl(
                  Icons.filter_list,
                  _filter,
                  _showFilterSheet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactControl(
                  Icons.sort,
                  _sort,
                  _showSortSheet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${filtered.length} request${filtered.length == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_filter != 'All')
                TextButton(
                  onPressed: () => setState(() => _filter = 'All'),
                  child: const Text('Clear filter'),
                ),
            ],
          ),
          const SizedBox(height: 2),
          if (filtered.isEmpty) _emptyState(),
          ...filtered.map(_requestCard),
        ],
      ),
    );
  }

  Widget _compactControl(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: Colors.black87,
        side: const BorderSide(color: Color(0xFFD8CEC7)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 42, color: _muted),
          SizedBox(height: 10),
          Text(
            'No matching requests',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 4),
          Text(
            'Try another filter or search term.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }

  List<AssistanceRequest> _visibleRequests(
    List<AssistanceRequest> source,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    Iterable<AssistanceRequest> result = source;

    if (_filter == 'Attention') {
      result = result.where(
        (r) => r.status == 'Requested' || r.status == 'At Station',
      );
    } else if (_filter == 'In Progress') {
      result = result.where(
        (r) => _activeStatuses.contains(r.status),
      );
    } else if (_filter != 'All') {
      result = result.where((r) => r.status == _filter);
    }

    if (query.isNotEmpty) {
      result = result.where((r) {
        final haystack = [
          r.passengerName,
          r.trainNo,
          r.pnr,
          r.coach,
          r.seat?.toString() ?? '',
          r.boardingStation,
          r.currentLocation ?? '',
        ].join(' ').toLowerCase();
        return haystack.contains(query);
      });
    }

    final list = result.toList();
    if (_sort == 'Priority') {
      list.sort(
        (a, b) => _priority(a.status).compareTo(_priority(b.status)),
      );
    } else if (_sort == 'Passenger') {
      list.sort(
        (a, b) => a.passengerName
            .toLowerCase()
            .compareTo(b.passengerName.toLowerCase()),
      );
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
    final terminal = _terminalStatuses.contains(req.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: status.color,
          width: req.status == 'At Station' ? 1.8 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () {
            setState(() {
              if (expanded) {
                _expanded.remove(req.id);
              } else {
                _expanded.add(req.id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: status.color,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              status.icon,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                req.status.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        req.passengerName.isEmpty
                            ? 'Passenger'
                            : req.passengerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 21,
                      color: _muted,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  req.trainNo.isEmpty
                      ? 'Train not specified'
                      : req.trainNo,
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${req.coach} • ${req.seat ?? 'Seat not specified'} • PNR ${req.pnr}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (req.boardingStation.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Boarding: ${req.boardingStation}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (req.platform?.isNotEmpty == true ||
                    req.currentLocation?.isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(
                    [
                      if (req.platform?.isNotEmpty == true)
                        'Platform ${req.platform}',
                      if (req.currentLocation?.isNotEmpty == true)
                        req.currentLocation!,
                    ].join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: expanded
                      ? _requestDetails(req, terminal)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
                Text(
                  expanded ? 'Tap to collapse' : 'Tap for details',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _requestDetails(
    AssistanceRequest req,
    bool terminal,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 22),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: req.assistanceType
              .map(
                (x) => Chip(
                  label: Text(x),
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
        ),
        if (req.notes?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            'Notes: ${req.notes}',
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
        if (req.passengerPhone.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Passenger: ${req.passengerPhone}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
        if (req.status == 'Escalated') ...[
          const SizedBox(height: 12),
          const Text(
            'Escalated to supervisor. Awaiting further action.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.deepOrange,
            ),
          ),
        ],
        if (!terminal && req.status != 'Escalated') ...[
          const SizedBox(height: 12),
          _actionButton(req),
          if (req.status == 'At Station' || req.status == 'Assigned') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _escalate(req),
              icon: const Icon(Icons.warning_amber),
              label: const Text('Escalate to supervisor'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepOrange,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _actionButton(AssistanceRequest req) {
    final action = switch (req.status) {
      'At Station' => (
          'Acknowledge Request',
          Icons.notifications_active,
        ),
      'Assigned' => (
          'Passenger Located',
          Icons.person_pin_circle,
        ),
      'Located' => (
          'Start Boarding',
          Icons.directions_walk,
        ),
      'Boarding' => (
          'Confirm Passenger Boarded',
          Icons.check_circle,
        ),
      'Boarded' => (
          'Complete Assistance',
          Icons.done_all,
        ),
      _ => (
          'Accept & Assign',
          Icons.assignment_ind_outlined,
        ),
    };

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
            await AssistanceWorkflowService().updateStatus(
              req.id,
              next,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_successMessage(next)),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not update request: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        icon: Icon(action.$2),
        label: Text(
          action.$1,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Future<void> _escalate(AssistanceRequest req) async {
    try {
      await AssistanceWorkflowService().escalate(req.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supervisor escalation sent.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not escalate: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  Widget _duty(List<AssistanceRequest> requests) {
    final active = requests
        .where((r) => !_terminalStatuses.contains(r.status))
        .toList();
    final groups = <String, List<AssistanceRequest>>{};

    for (final request in active) {
      final station = request.boardingStation.trim().isEmpty
          ? 'Station not specified'
          : request.boardingStation.trim();
      groups.putIfAbsent(station, () => <AssistanceRequest>[]).add(request);
    }

    final stations = groups.keys.toList()..sort();

    if (stations.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [_emptyDutyState()],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, color: _blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${active.length} active passenger${active.length == 1 ? '' : 's'} across ${stations.length} station${stations.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...stations.map(
          (station) => _stationGroup(
            station,
            groups[station]!,
          ),
        ),
      ],
    );
  }

  Widget _stationGroup(
    String station,
    List<AssistanceRequest> requests,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE1D8D1)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15),
        childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
        leading: const Icon(Icons.location_on_outlined, color: _blue),
        title: Text(
          station,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${requests.length} passenger${requests.length == 1 ? '' : 's'}',
        ),
        children: requests
            .map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  r.passengerName.isEmpty ? 'Passenger' : r.passengerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${r.trainNo} • ${r.coach} • ${r.seat ?? 'Seat not specified'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(
                  _statusStyle(r.status).icon,
                  color: _statusStyle(r.status).color,
                ),
                onTap: () => _openRequests(
                  r.status,
                  expandedId: r.id,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _emptyDutyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.location_off_outlined, size: 42, color: _muted),
          SizedBox(height: 10),
          Text(
            'No active station duty',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 4),
          Text(
            'Active assistance requests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _profile(dynamic user, String staffName) {
    final username = user?.username?.toString() ?? '';
    final email = user?.email?.toString() ?? '';
    final phone = user?.phone?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 34,
            backgroundColor: _blue,
            child: Text(
              staffName.isEmpty ? 'S' : staffName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            staffName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Railway Staff',
            style: TextStyle(color: _muted),
          ),
        ),
        const SizedBox(height: 22),
        _profileTile(
          Icons.badge_outlined,
          'Username',
          username.isEmpty ? 'Not provided' : username,
        ),
        _profileTile(
          Icons.email_outlined,
          'Email',
          email.isEmpty ? 'Not provided' : email,
        ),
        _profileTile(
          Icons.phone_outlined,
          'Phone',
          phone.isEmpty ? 'Not provided' : phone,
        ),
        _profileTile(
          Icons.verified_user_outlined,
          'Role',
          'Staff',
        ),
      ],
    );
  }

  Widget _profileTile(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: _blue),
        title: Text(
          title,
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
        subtitle: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    final options = [
      'All',
      'Attention',
      'Requested',
      'At Station',
      'In Progress',
      'Assigned',
      'Located',
      'Boarding',
      'Boarded',
      'Completed',
      'Escalated',
      'Cancelled',
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: options
              .map(
                (option) => ListTile(
                  leading: Icon(
                    option == _filter
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: option == _filter ? _blue : _muted,
                  ),
                  title: Text(option),
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() => _filter = selected);
    }
  }

  Future<void> _showSortSheet() async {
    final options = ['Priority', 'Passenger', 'Train'];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: options
              .map(
                (option) => ListTile(
                  leading: Icon(
                    option == _sort
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: option == _sort ? _blue : _muted,
                  ),
                  title: Text(option),
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() => _sort = selected);
    }
  }

  void _openRequests(
    String filter, {
    String? expandedId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StaffDashboard(
          initialTab: 1,
          initialFilter: filter,
          initialExpandedId: expandedId,
        ),
      ),
    );
  }

  int _count(
    List<AssistanceRequest> requests,
    String status,
  ) {
    return requests.where((r) => r.status == status).length;
  }

  ({Color color, IconData icon}) _statusStyle(String status) {
    switch (status) {
      case 'At Station':
        return (
          color: Colors.deepOrange,
          icon: Icons.location_on,
        );
      case 'Assigned':
        return (
          color: _blue,
          icon: Icons.assignment_ind_outlined,
        );
      case 'Located':
        return (
          color: Colors.teal,
          icon: Icons.person_pin_circle,
        );
      case 'Boarding':
        return (
          color: Colors.indigo,
          icon: Icons.directions_walk,
        );
      case 'Boarded':
        return (
          color: Colors.green,
          icon: Icons.check_circle_outline,
        );
      case 'Completed':
        return (
          color: Colors.green.shade800,
          icon: Icons.done_all,
        );
      case 'Cancelled':
        return (
          color: Colors.grey,
          icon: Icons.cancel_outlined,
        );
      case 'Escalated':
        return (
          color: Colors.deepOrange.shade700,
          icon: Icons.warning_amber,
        );
      default:
        return (
          color: Colors.orange.shade800,
          icon: Icons.hourglass_empty,
        );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: .8,
      ),
    );
  }
}
