import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';

class RequestForm extends StatefulWidget {
  const RequestForm({super.key});

  @override
  State<RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<RequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _pnrController = TextEditingController();
  final _trainController = TextEditingController();
  final _coachController = TextEditingController();
  final _notesController = TextEditingController();

  // List of possible assistance types
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
    _trainController.dispose();
    _coachController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitForm() async {
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

    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<RequestProvider>(context, listen: false);
      
      final success = await provider.submitRequest(
        pnr: _pnrController.text.trim(),
        trainNo: _trainController.text.trim(),
        coach: _coachController.text.trim().toUpperCase(),
        assistanceType: selectedAssistance,
        notes: _notesController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Assistance requested successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context);
      }
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
                'Please enter your booking details and specify your accessibility needs. This details will be shared with the railway station staff.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // PNR Number Input (Exactly 10 digits validation)
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
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your PNR number';
                  }
                  if (value.trim().length != 10 || int.tryParse(value) == null) {
                    return 'PNR must be exactly 10 numeric digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Train Number Input
              TextFormField(
                controller: _trainController,
                decoration: InputDecoration(
                  labelText: 'Train Number / Name',
                  prefixIcon: const Icon(Icons.train),
                  hintText: 'e.g. 12626 Kerala Express',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the Train Number or Name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Coach Number Input
              TextFormField(
                controller: _coachController,
                decoration: InputDecoration(
                  labelText: 'Coach Number',
                  prefixIcon: const Icon(Icons.door_sliding),
                  hintText: 'e.g. S1, B2, A1, Gen',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please specify the coach number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Assistance Checkboxes heading
              const Text(
                'Select Assistance Required:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Assistance Checkboxes
              ..._assistanceOptions.map((opt) {
                return CheckboxListTile(
                  title: Text(opt['title']),
                  value: opt['checked'],
                  secondary: Icon(opt['icon'], color: Colors.orange.shade800),
                  onChanged: (bool? val) {
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

              // Additional Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Additional Notes / Specific Needs',
                  hintText: 'e.g., "Need wheelchair boarding ramp on platform 4. Passenger is blind and has a heavy trolley bag."',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
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
