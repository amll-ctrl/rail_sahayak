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
  static const _blue = Color(0xFF303F9F);
  static const _surface = Color(0xFFFFF4EC);
  String _filter = 'All';
  final Set<String> _expandedRequests = <String>{};

  List<AssistanceRequest> _filteredRequests(List<AssistanceRequest> requests) {
    if (_filter == 'All') return requests;
    return requests.where((r) => r.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final currentStaff = provider.currentUser;
    final requests = _filteredRequests(provider.staffRequests);
    final staffName = currentStaff?.name.trim().isNotEmpty == true
        ? currentStaff!.name.trim()
        : 'Railway Staff';

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      appBar: AppBar(
        title: const Text('Staff Support Console', style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: provider.isLoading ? null : provider.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 250)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: _blue,
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Station Duty: $staffName', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Assisting passengers with disabilities and boardings.', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 78,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterButton('All', Icons.check),
                    _filterButton('Requested', Icons.hourglass_empty),
                    _filterButton('Assigned', Icons.assignment_ind_outlined),
                    _filterButton('Assisting', Icons.directions_walk),
                    _filterButton('Completed', Icons.check_circle_outline),
                  ],
                ),
              ),
            ),
            if (requests.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Card(color: _surface, child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No assistance requests in this category.')))),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _requestCard(context, requests[index], currentStaff),
                    childCount: requests.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterButton(String label, IconData icon) {
    final selected = _filter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: OutlinedButton.icon(
        onPressed: () => setState(() => _filter = label),
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? _blue : const Color(0xFFF5F0EC),
          foregroundColor: selected ? Colors.white : Colors.black87,
          side: BorderSide(color: selected ? _blue : const Color(0xFFD8CEC7), width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _requestCard(BuildContext context, AssistanceRequest req, dynamic currentStaff) {
    final provider = context.read<RequestProvider>();
    final isExpanded = _expandedRequests.contains(req.id);
    final isAssignedToMe = req.staffId == currentStaff?.id;
    final status = req.status;
    final statusData = _statusStyle(status);
    final assistance = req.assistanceType.isEmpty ? 'Assistance' : req.assistanceType.join(', ');
    final canAct = status != 'Completed' && status != 'Cancelled';

    String actionLabel;
    IconData actionIcon;
    if (status == 'Requested') {
      actionLabel = 'Accept Request';
      actionIcon = Icons.check;
    } else if (status == 'Assigned' && !isAssignedToMe) {
      actionLabel = 'Take Request';
      actionIcon = Icons.assignment_ind_outlined;
    } else if (status == 'Assigned') {
      actionLabel = 'Start Assisting';
      actionIcon = Icons.directions_walk;
    } else if (status == 'Assisting' && !isAssignedToMe) {
      actionLabel = 'Take Over Request';
      actionIcon = Icons.swap_horiz;
    } else {
      actionLabel = 'Passenger Boarded';
      actionIcon = Icons.check_circle_outline;
    }

    Future<void> handleAction() async {
      if (status == 'Requested') {
        await provider.updateRequestStatus(req.id, 'Assigned');
      } else if (status == 'Assigned' && !isAssignedToMe) {
        await provider.updateRequestStatus(req.id, 'Assigned');
      } else if (status == 'Assigned' && isAssignedToMe) {
        await provider.updateRequestStatus(req.id, 'Assisting');
      } else if (status == 'Assisting' && !isAssignedToMe) {
        await provider.updateRequestStatus(req.id, 'Assigned');
        await provider.updateRequestStatus(req.id, 'Assisting');
      } else if (status == 'Assisting' && isAssignedToMe) {
        await provider.updateRequestStatus(req.id, 'Completed');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: status == 'Completed' ? _blue : const Color(0xFFFFC978), width: status == 'Completed' ? 2 : 1.2),
        boxShadow: const [BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Color(0x18000000))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () => setState(() => isExpanded ? _expandedRequests.remove(req.id) : _expandedRequests.add(req.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 125),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(color: statusData.color, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusData.icon, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Flexible(child: Text(status.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('PNR: ${req.pnr}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down, size: 25),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person, color: _blue, size: 21),
                    const SizedBox(width: 9),
                    Expanded(
                      flex: 5,
                      child: Text(req.passengerName.isEmpty ? 'Passenger' : req.passengerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: Text(req.trainNo.isEmpty ? 'Train' : req.trainNo, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: isExpanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 22),
                            Row(
                              children: [
                                Expanded(child: _infoTile(Icons.phone, req.passengerPhone.isEmpty ? 'No phone' : req.passengerPhone)),
                                const SizedBox(width: 10),
                                Expanded(child: _infoTile(Icons.meeting_room, 'Coach: ${req.coach}')),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(color: const Color(0xFFF0EEF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD6D1E1))),
                              child: Text(assistance, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                            ),
                            if (req.upgradeRequested || req.travelClass != 'Not specified') ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: req.upgradeRequested ? const Color(0xFFFFF3E0) : const Color(0xFFF4F4F4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: req.upgradeRequested ? const Color(0xFFFFCC80) : const Color(0xFFE0E0E0)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(req.upgradeRequested ? Icons.upgrade : Icons.airline_seat_recline_normal, color: req.upgradeRequested ? Colors.deepOrange : Colors.grey.shade700),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        req.upgradeRequested
                                            ? 'Full fare / higher class requested • ${req.travelClass}'
                                            : 'Travel class: ${req.travelClass}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (req.staffName != null && req.staffName!.isNotEmpty) ...[
                              const SizedBox(height: 9),
                              Text(status == 'Completed' ? 'Done by: ${req.staffName}' : 'Assigned to: ${req.staffName}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                            if (canAct) ...[
                              const Divider(height: 25),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: provider.isLoading ? null : handleAction,
                                  icon: Icon(actionIcon, size: 19),
                                  label: Text(actionLabel),
                                  style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, disabledForegroundColor: Colors.grey.shade700, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                ),
                              ),
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 3),
                Text(isExpanded ? 'Tap to collapse' : 'Tap for request details', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(9)),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 18),
          const SizedBox(width: 7),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  ({Color color, IconData icon}) _statusStyle(String status) {
    switch (status) {
      case 'Requested':
        return (color: const Color(0xFFFF9800), icon: Icons.hourglass_empty);
      case 'Assigned':
        return (color: _blue, icon: Icons.assignment_ind_outlined);
      case 'Assisting':
        return (color: const Color(0xFFEF6C00), icon: Icons.directions_walk);
      case 'Completed':
        return (color: const Color(0xFF43A047), icon: Icons.check_circle);
      case 'Cancelled':
        return (color: const Color(0xFF757575), icon: Icons.cancel_outlined);
      default:
        return (color: _blue, icon: Icons.info_outline);
    }
  }
}
