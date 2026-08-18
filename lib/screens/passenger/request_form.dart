import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/railway_catalog.dart';
import '../../providers/request_provider.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one type of assistance required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedTrain == null || _selectedCoach == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a train and coach.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final provider = Provider.of<RequestProvider>(context, listen: false);

    final success = await provider.submitRequest(
      pnr: _pnrController.text.trim(),
      trainNo: _selectedTrain!.label,
      coach: _selectedCoach!,
      assistanceType: selectedAssistance,
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Assistance request sent to railway staff!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send the request. Please check your connection and try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<RequestProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Assistance'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Request Assistance Form',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your train and coach from the available options. This information will be shared with railway station staff.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _pnrController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: 'PNR Number (10 digits)',
                  prefixIcon: const Icon(Icons.confirmation_number),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  helperText: 'Found on your ticket printout or SMS.',
                ),
                validator: (value) {
                  final pnr = value?.trim() ?? '';
                  if (pnr.isEmpty) return 'Please enter your PNR number';
                  if (pnr.length != 10 || int.tryParse(pnr) == null) {
                    return 'PNR must be exactly 10 numeric digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<RailwayTrain>(
                value: _selectedTrain,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Train',
                  prefixIcon: const Icon(Icons.train),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                hint: const Text('Select your train'),
                items: railwayTrains.map((train) {
                  return DropdownMenuItem<RailwayTrain>(
                    value: train,
                    child: Text(
                      train.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: isLoading
                    ? null
                    : (train) {
                        setState(() {
                          _selectedTrain = train;
                          _selectedCoach = null;
                        });
                      },
                validator: (value) =>
                    value == null ? 'Please select your train' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCoach,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Coach Number',
                  prefixIcon: const Icon(Icons.door_sliding),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                hint: Text(
                  _selectedTrain == null
                      ? 'Select a train first'
                      : 'Select your coach',
                ),
                items: _selectedTrain?.coaches.map((coach) {
                  return DropdownMenuItem<String>(
                    value: coach,
                    child: Text(coach),
                  );
                }).toList(),
                onChanged: isLoading || _selectedTrain == null
                    ? null
                    : (coach) {
                        setState(() {
                          _selectedCoach = coach;
                        });
                      },
                validator: (value) =>
                    value == null ? 'Please select your coach' : null,
              ),
              const SizedBox(height: 24),

              const Text(
                'Select Assistance Required:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              ..._assistanceOptions.map((opt) {
                return CheckboxListTile(
                  title: Text(opt['title']),
                  value: opt['checked'],
                  secondary: Icon(opt['icon'], color: Colors.orange.shade800),
                  onChanged: isLoading
                      ? null
                      : (bool? val) {
                          setState(() {
                            opt['checked'] = val ?? false;
                          });
                        },
                  activeColor: Colors.orange.shade800,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                maxLines: 3,
                enabled: !isLoading,
                decoration: InputDecoration(
                  labelText: 'Additional Notes / Specific Needs',
                  hintText: 'e.g. Need wheelchair boarding ramp on platform 4.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Assistance Request',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
