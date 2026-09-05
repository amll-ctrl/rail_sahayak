import 'package:flutter/material.dart';

import '../../models/train_info.dart';
import '../../services/train_service.dart';

class TrainStatusScreen extends StatefulWidget {
  final String? initialTrainNumber;

  const TrainStatusScreen({super.key, this.initialTrainNumber});

  @override
  State<TrainStatusScreen> createState() => _TrainStatusScreenState();
}

class _TrainStatusScreenState extends State<TrainStatusScreen> {
  final _controller = TextEditingController();
  final _service = TrainService();
  TrainInfo? _info;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialTrainNumber ?? '';
    if (_controller.text.length == 5) _lookup();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    FocusScope.of(context).unfocus();
    final number = _controller.text.trim();
    if (!RegExp(r'^\d{5}$').hasMatch(number)) {
      setState(() => _error = 'Enter a valid 5-digit train number.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final result = await _service.getTrainInfo(number);
      if (!mounted) return;
      setState(() => _info = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF57C00);
    final info = _info;

    return Scaffold(
      appBar: AppBar(title: const Text('Train Information'), backgroundColor: orange, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 5,
            decoration: InputDecoration(labelText: 'Train number', hintText: 'e.g. 12002', prefixIcon: const Icon(Icons.train), suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _loading ? null : _lookup), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            onSubmitted: (_) => _lookup(),
          ),
          if (_loading) ...[const SizedBox(height: 24), const Center(child: CircularProgressIndicator())],
          if (_error != null) ...[const SizedBox(height: 16), Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.red))))],
          if (info != null) ...[
            const SizedBox(height: 20),
            Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${info.number} — ${info.name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('${info.sourceCode ?? 'Source'} → ${info.destinationCode ?? 'Destination'}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(info.delayMinutes == 0 ? 'On time' : '${info.delayMinutes} min delay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: info.delayMinutes == 0 ? Colors.green.shade700 : Colors.red.shade700)),
              if (info.currentStation != null) ...[const SizedBox(height: 8), Text('Current location: ${info.currentStation}', style: const TextStyle(fontSize: 16))],
              if (info.lastUpdatedAt != null) ...[const SizedBox(height: 8), Text('Last updated: ${info.lastUpdatedAt}', style: const TextStyle(color: Colors.grey))],
            ]))),
            const SizedBox(height: 16),
            const Text('Route & timings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...info.stops.map((stop) => _StopTile(stop: stop)),
          ],
          const SizedBox(height: 24),
          const Text('Live data depends on the configured railway data provider. Always verify critical journey information with official Indian Railways/IRCTC channels.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  final TrainStop stop;
  const _StopTile({required this.stop});

  @override
  Widget build(BuildContext context) {
    final arrival = stop.actualArrival ?? stop.scheduledArrival ?? '—';
    final departure = stop.actualDeparture ?? stop.scheduledDeparture ?? '—';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text('${stop.sequence}')),
        title: Text(stop.stationName.isEmpty ? stop.stationCode : stop.stationName),
        subtitle: Text('${stop.stationCode}  •  Arrive $arrival  •  Depart $departure${stop.platform == null ? '' : '  •  PF ${stop.platform}'}'),
        trailing: stop.delayMinutes == null || stop.delayMinutes == 0 ? null : Text('+${stop.delayMinutes}m', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
