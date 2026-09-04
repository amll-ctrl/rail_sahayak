import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/railway_catalog.dart';
import '../../models/assistance_request.dart';
import '../../providers/request_provider.dart';
import 'train_status_screen.dart';

class RequestForm extends StatefulWidget {
  const RequestForm({super.key});

  @override
  State<RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<RequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _pnrController = TextEditingController();
  final _notesController = TextEditingController();

  RailwayTrain? _selectedTrain;
  String? _selectedCoach;
  String _travelClass = 'Not specified';
  String _farePreference = 'concession';
  bool _upgradeRequested = false;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _assistanceOptions = [
    {'title': 'Wheelchair Assistance', 'checked': false, 'icon': Icons.wheelchair_pickup},
    {'title': 'Luggage Porter Support', 'checked': false, 'icon': Icons.luggage},
    {'title': 'Visual Guidance / Escort', 'checked': false, 'icon': Icons.visibility},
    {'title': 'Elderly Mobility Escort', 'checked': false, 'icon': Icons.elderly},
    {'title': 'Hearing & Sign Support', 'checked': false, 'icon': Icons.hearing},
  ];

  @override
  void dispose() {
    _pnrController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final selectedAssistance = _assistanceOptions
        .where((opt) => opt['checked'] == true)
        .map((opt) => opt['title'] as String)
        .toList();

    if (selectedAssistance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select at least one type of assistance required.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTrain == null || _selectedCoach == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a train and coach.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final provider = Provider.of<RequestProvider>(context, listen: false);
    final user = provider.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      final request = AssistanceRequest(
        id: '',
        pnr: _pnrController.text.trim(),
        trainNo: _selectedTrain!.label,
        trainNumber: _selectedTrain!.number,
        coach: _selectedCoach!,
        passengerId: user.id,
        passengerName: user.name,
        passengerPhone: user.phone,
        status: 'Requested',
        assistanceType: selectedAssistance,
        timestamp: DateTime.now(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        travelClass: _travelClass,
        farePreference: _farePreference,
        upgradeRequested: _upgradeRequested,
      );

      await FirebaseFirestore.instance.collection('requests').add(request.toMap());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Assistance request sent to railway staff!'),
        backgroundColor: Colors.green.shade700,
      ));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not send the request. Please check your connection and try again.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isSubmitting;
    const orange = Color(0xFFF57C00);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Assistance'),
        backgroundColor: orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Request Assistance Form', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Select your train and coach. Railway staff will use this information to assist you.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _pnrController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: 'PNR Number (10 digits)',
                  prefixIcon: const Icon(Icons.confirmation_number),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  final pnr = value?.trim() ?? '';
                  if (pnr.isEmpty) return 'Please enter your PNR number';
                  if (pnr.length != 10 || int.tryParse(pnr) == null) return 'PNR must be exactly 10 numeric digits';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<RailwayTrain>(
                value: _selectedTrain,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Train', prefixIcon: const Icon(Icons.train), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                hint: const Text('Select your train'),
                items: railwayTrains.map((train) => DropdownMenuItem<RailwayTrain>(value: train, child: Text(train.label, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: busy ? null : (train) => setState(() { _selectedTrain = train; _selectedCoach = null; }),
                validator: (value) => value == null ? 'Please select your train' : null,
              ),
              if (_selectedTrain != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrainStatusScreen(initialTrainNumber: _selectedTrain!.number))),
                  icon: const Icon(Icons.my_location),
                  label: const Text('View live location & timings'),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCoach,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Coach Number', prefixIcon: const Icon(Icons.door_sliding), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                hint: Text(_selectedTrain == null ? 'Select a train first' : 'Select your coach'),
                items: _selectedTrain?.coaches.map((coach) => DropdownMenuItem<String>(value: coach, child: Text(coach))).toList(),
                onChanged: busy || _selectedTrain == null ? null : (coach) => setState(() => _selectedCoach = coach),
                validator: (value) => value == null ? 'Please select your coach' : null,
              ),
              const SizedBox(height: 24),
              const Text('Travel class & fare preference', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _travelClass,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Travel class', prefixIcon: const Icon(Icons.airline_seat_recline_normal), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: const ['Not specified', '2S', 'SL', 'CC', '3E', '3A', '2A', '1A', 'EC', 'EA'].map((c) => DropdownMenuItem(value: c, child: Text(c == 'Not specified' ? c : 'Class $c'))).toList(),
                onChanged: busy ? null : (value) => setState(() => _travelClass = value ?? 'Not specified'),
              ),
              const SizedBox(height: 12),
              RadioListTile<String>(
                value: 'concession',
                groupValue: _farePreference,
                onChanged: busy ? null : (value) => setState(() { _farePreference = value!; _upgradeRequested = false; }),
                title: const Text('Use eligible Divyangjan concession'),
                subtitle: const Text('Concession eligibility is governed by Indian Railways rules.'),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                value: 'full_fare',
                groupValue: _farePreference,
                onChanged: busy ? null : (value) => setState(() { _farePreference = value!; _upgradeRequested = true; }),
                title: const Text('Pay full fare / request higher class'),
                subtitle: const Text('Keep the same RailSahayak assistance while travelling in your preferred class.'),
                contentPadding: EdgeInsets.zero,
              ),
              if (_upgradeRequested)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
                  child: const Text('This records your full-fare/higher-class preference for the assistance team. RailSahayak does not itself issue or modify railway tickets; ticketing remains subject to Indian Railways/IRCTC rules and availability.'),
                ),
              const SizedBox(height: 20),
              const Text('Select Assistance Required:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._assistanceOptions.map((opt) => CheckboxListTile(
                    title: Text(opt['title']),
                    value: opt['checked'],
                    secondary: Icon(opt['icon'], color: orange),
                    onChanged: busy ? null : (val) => setState(() => opt['checked'] = val ?? false),
                    activeColor: orange,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  )),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                enabled: !busy,
                decoration: InputDecoration(labelText: 'Additional Notes / Specific Needs', hintText: 'e.g. Need wheelchair boarding ramp on platform 4.', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: busy ? null : _submitForm,
                style: ElevatedButton.styleFrom(backgroundColor: orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Submit Assistance Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
