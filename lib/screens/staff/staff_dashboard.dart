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
                    Text(
                      'Active Station Duty: $staffName',
                      style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Acknowledge, locate and board passengers who need assistance.',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 78,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  children: [
                    _filterButton('All', Icons.check),
                    _filterButton('At Station', Icons.location_on),
                    _filterButton('Assigned', Icons.assignment_ind_outlined),
                    _filterButton('Located', Icons.person_pin_circle),
                    _filterButton('Boarding', Icons.directions_walk),
                    _filterButton('Boarded', Icons.check_circle_outline),
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
                      child: Center(child: Text('No assistance requests in this category.')),
                    ),
                  ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _requestCard(BuildContext context, AssistanceRequest req, dynamic currentStaff) {
    final expanded = _expandedRequests.contains(req.id);
    final status = req.status;
    final statusData = _statusStyle(status);
    final terminal = status == 'Completed' || status == 'Cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: statusData.color, width: status == 'At Station' ? 2 : 1.2),
        boxShadow: const [BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Color(0x18000000))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () => setState(
            () => expanded ? _expandedRequests.remove(req.id) : _expandedRequests.add(req.id),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(color: statusData.color, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusData.icon, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            status.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        req.passengerName.isEmpty ? 'Passenger' : req.passengerName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      req.trainNo.isEmpty ? 'Train' : req.trainNo,
                      style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  '${req.coach} • ${req.seat ?? 'Seat not specified'}  •  PNR ${req.pnr}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (req.boardingStation.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text('Boarding: ${req.boardingStation}', style: const TextStyle(color: Colors.black87)),
                ],
                if (req.platform?.isNotEmpty == true || req.currentLocation?.isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(
                    [
                      if (req.platform?.isNotEmpty == true) 'Platform ${req.platform}',
                      if (req.currentLocation?.isNotEmpty == true) req.currentLocation!,
                    ].join(' • '),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: expanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 22),
                            Wrap(
                              spacing: 7,
                              runSpacing: 6,
                              children: req.assistanceType
                                  .map((x) => Chip(label: Text(x), visualDensity: VisualDensity.compact))
                                  .toList(),
                            ),
                            if (req.notes?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text('Notes: ${req.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                            if (req.passengerPhone.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Passenger: ${req.passengerPhone}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (!terminal) _actionButton(context, req),
                            if (!terminal && (status == 'At Station' || status == 'Assigned')) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _escalate(context, req),
                                icon: const Icon(Icons.warning_amber),
                                label: const Text('Escalate to supervisor'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.deepOrange,
                                  minimumSize: const Size(double.infinity, 44),
                                ),
                              ),
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
                Text(
                  expanded ? 'Tap to collapse' : 'Tap for request details',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_successMessage(next)), backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not update request: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Future<void> _escalate(BuildContext context, AssistanceRequest req) async {
    try {
      await AssistanceWorkflowService().escalate(req.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supervisor escalation sent.'), backgroundColor: Colors.deepOrange),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not escalate: $e'), backgroundColor: Colors.red),
        );
      }
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
        return (color: Colors.green.shade700, icon: Icons.check_circle);
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
