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
        title: const Text(
          'Staff Support Console',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: _blue,
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Station Duty: $staffName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Assisting passengers with disabilities and boardings.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 86,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
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
                  child: Card(
                    color: _surface,
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                        child: Text('No assistance requests in this category.'),
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _requestCard(
                      context,
                      requests[index],
                      currentStaff,
                    ),
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
      padding: const EdgeInsets.only(right: 14),
      child: OutlinedButton.icon(
        onPressed: () => setState(() => _filter = label),
        icon: Icon(icon, size: 19),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? _blue : const Color(0xFFF5F0EC),
          foregroundColor: selected ? Colors.white : Colors.black87,
          side: BorderSide(
            color: selected ? _blue : const Color(0xFFD8CEC7),
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
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
    final status = req.status;
    final statusData = _statusStyle(status);
    final assistance = req.assistanceType.isEmpty
        ? 'Assistance'
        : req.assistanceType.join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: status == 'Completed' ? _blue : const Color(0xFFFFC978),
          width: status == 'Completed' ? 2.5 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 3),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: statusData.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusData.icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'PNR: ${req.pnr}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            Row(
              children: [
                const Icon(Icons.person, color: _blue, size: 23),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    req.passengerName.isEmpty ? 'Passenger' : req.passengerName,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.phone, color: Colors.grey, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    req.passengerPhone.isEmpty ? 'No phone' : req.passengerPhone,
                    style: const TextStyle(fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _infoTile(
                    Icons.train,
                    req.trainNo.isEmpty ? 'Train' : req.trainNo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _infoTile(Icons.meeting_room, 'Coach: ${req.coach}'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EEF7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD6D1E1)),
              ),
              child: Text(
                assistance,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
            if (req.staffName != null && req.staffName!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Assigned to: ${req.staffName}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
            if (status != 'Completed' && status != 'Cancelled') ...[
              const Divider(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (status == 'Requested') {
                      provider.updateRequestStatus(req.id, 'Assigned');
                    } else if (status == 'Assigned' && isAssignedToMe) {
                      provider.updateRequestStatus(req.id, 'Assisting');
                    } else if (status == 'Assisting' && isAssignedToMe) {
                      provider.updateRequestStatus(req.id, 'Completed');
                    }
                  },
                  icon: Icon(
                    status == 'Requested'
                        ? Icons.check
                        : status == 'Assigned'
                            ? Icons.directions_walk
                            : Icons.check_circle_outline,
                  ),
                  label: Text(
                    status == 'Requested'
                        ? 'Accept Request'
                        : status == 'Assigned'
                            ? (isAssignedToMe ? 'Start Assisting' : 'Assigned to another staff')
                            : 'Passenger Boarded',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
