import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../models/assistance_request.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final user = provider.currentUser;
    final allRequests = provider.staffRequests;

    // Filter requests based on chip selection
    List<AssistanceRequest> filteredRequests = allRequests;
    if (_selectedFilter != 'All') {
      filteredRequests = allRequests.where((req) => req.status.toLowerCase() == _selectedFilter.toLowerCase()).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Support Console', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo.shade800,
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
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome header banner for Staff
                Container(
                  color: Colors.indigo.shade800,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Station Duty: ${user.name}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Assisting passengers with disabilities and boardings.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                
                // Horizontal Status Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: ['All', 'Requested', 'Assigned', 'Assisting', 'Completed'].map((status) {
                      final isSelected = _selectedFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedFilter = status;
                              });
                            }
                          },
                          selectedColor: Colors.indigo.shade800,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Requests List view
                Expanded(
                  child: filteredRequests.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredRequests.length,
                          itemBuilder: (context, index) {
                            final req = filteredRequests[index];
                            return _buildStaffRequestCard(context, req, provider);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No assistance requests in status "$_selectedFilter"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffRequestCard(BuildContext context, AssistanceRequest req, RequestProvider provider) {
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

    final isAssignedToMe = req.staffId == provider.currentUser?.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAssignedToMe ? Colors.indigo.shade800 : statusColor.withOpacity(0.3),
          width: isAssignedToMe ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Status + PNR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  avatar: Icon(statusIcon, color: Colors.white, size: 14),
                  label: Text(
                    req.status.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  backgroundColor: statusColor,
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  'PNR: ${req.pnr}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const Divider(height: 16),

            // Passenger Name & details
            Row(
              children: [
                Icon(Icons.person, color: Colors.indigo.shade800),
                const SizedBox(width: 8),
                Text(
                  req.passengerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Icon(Icons.phone, color: Colors.grey.shade600, size: 18),
                const SizedBox(width: 4),
                Text(req.passengerPhone, style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),

            // Train & Coach Details
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.train, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    req.trainNo,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.door_sliding, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Coach: ${req.coach}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Assistance items
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: req.assistanceType.map((type) => Chip(
                label: Text(type, style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.indigo.shade50,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),

            if (req.notes != null && req.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${req.notes}',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade800, fontSize: 13),
              ),
            ],

            if (req.staffName != null && !isAssignedToMe) ...[
              const SizedBox(height: 8),
              Text(
                'Assigned to: ${req.staffName}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
              ),
            ],

            // Action triggers for staff
            if (req.status != 'Completed' && req.status != 'Cancelled') ...[
              const Divider(height: 24),
              Row(
                children: [
                  // Claim / Assign button
                  if (req.status == 'Requested')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          provider.updateRequestStatus(
                            req.id,
                            'Assigned',
                            staffId: provider.currentUser!.id,
                            staffName: provider.currentUser!.name,
                          );
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

                  // Assisting transition button
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

                  // Complete assistance button
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
extension ChoiceChipExtension on ChoiceChip {
  Color? get textColor => labelStyle?.color;
}
