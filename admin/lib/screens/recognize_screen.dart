import 'package:flutter/material.dart';

import '../models/employee.dart';
import '../models/recognition_result.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/embedding_generator.dart';

/// Simulates capturing a face and asks the backend to recognize it.
///
/// Because there is no real camera step here, you pick which employee to "stand
/// in front of the camera" (or an unknown person) and the screen generates an
/// embedding from that identity, then sends it to /api/faces/recognize. This is
/// an admin tool for testing recognition and tuning the similarity threshold.
class RecognizeScreen extends StatefulWidget {
  const RecognizeScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<RecognizeScreen> createState() => _RecognizeScreenState();
}

class _RecognizeScreenState extends State<RecognizeScreen> {
  final _generator = const EmbeddingGenerator();

  late Future<List<Employee>> _employeesFuture;
  Employee? _selected; // null => "Unknown person"
  bool _busy = false;
  RecognitionResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _employeesFuture = widget.api.listEmployees();
  }

  Future<void> _recognize() async {
    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });
    try {
      final seed = _selected == null
          ? 'unknown-person-${DateTime.now().millisecondsSinceEpoch}'
          : 'employee-${_selected!.id}';
      final embedding = _generator.capture(seed);
      final result = await widget.api.recognizeFace(embedding);
      setState(() => _result = result);
    } on ApiException catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recognize face')),
      body: FutureBuilder<List<Employee>>(
        future: _employeesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final employees = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Choose who is "in front of the camera", then run recognition. '
                'Pick "Unknown person" to test a non-match.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: _selected?.id,
                decoration: const InputDecoration(
                  labelText: 'Simulated capture',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Unknown person'),
                  ),
                  for (final e in employees)
                    DropdownMenuItem<int?>(value: e.id, child: Text(e.name)),
                ],
                onChanged: (id) => setState(() {
                  _selected = id == null
                      ? null
                      : employees.firstWhere((e) => e.id == id);
                }),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _recognize,
                icon: const Icon(Icons.search),
                label: const Text('Recognize'),
              ),
              const SizedBox(height: 24),
              if (_busy) const Center(child: CircularProgressIndicator()),
              if (_error != null) _ResultCard.error(_error!),
              if (_result != null) _ResultCard.forResult(_result!),
            ],
          );
        },
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? detail;

  factory _ResultCard.forResult(RecognitionResult r) {
    if (r.matched) {
      return _ResultCard(
        color: Colors.green,
        icon: Icons.check_circle,
        title: 'Matched: ${r.employeeName ?? 'Employee ${r.employeeId}'}',
        detail: r.similarity == null
            ? null
            : 'Similarity: ${r.similarity!.toStringAsFixed(4)}',
      );
    }
    return const _ResultCard(
      color: Colors.orange,
      icon: Icons.help_outline,
      title: 'No match',
      detail: 'No registered face cleared the similarity threshold.',
    );
  }

  factory _ResultCard.error(String message) => _ResultCard(
        color: Colors.red,
        icon: Icons.error_outline,
        title: 'Error',
        detail: message,
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title),
        subtitle: detail == null ? null : Text(detail!),
      ),
    );
  }
}
