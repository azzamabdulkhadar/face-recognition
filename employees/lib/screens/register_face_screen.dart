import 'package:flutter/material.dart';

import '../models/employee.dart';
import '../models/face_info.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/face_embedder.dart';
import 'face_capture_screen.dart';

/// Employee self-service face registration.
///
/// The employee selects their name from the directory, then captures a live,
/// verified face. An embedding is generated on-device and sent to
/// /api/faces/register. Each employee can register exactly one face; once a
/// face exists the backend rejects a second registration (409).
class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<RegisterFaceScreen> createState() => _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends State<RegisterFaceScreen> {
  final _embedder = FaceEmbedder();

  late Future<List<Employee>> _employeesFuture;
  Employee? _selected;

  FaceInfo? _face; // existing face for the selected employee, if any
  bool _checkingFace = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _employeesFuture = widget.api.listEmployees();
  }

  @override
  void dispose() {
    _embedder.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onEmployeeChanged(Employee? employee) async {
    setState(() {
      _selected = employee;
      _face = null;
    });
    if (employee == null) return;

    setState(() => _checkingFace = true);
    try {
      final face = await widget.api.getFace(employee.id);
      if (mounted) setState(() => _face = face);
    } on ApiException catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _checkingFace = false);
    }
  }

  Future<void> _register() async {
    final employee = _selected;
    if (employee == null) return;

    // Open the camera, detect + verify a live face, and get a real embedding.
    final capture = await Navigator.of(context).push<FaceCaptureResult>(
      MaterialPageRoute(
        builder: (_) => FaceCaptureScreen(
          purpose: FaceCapturePurpose.checkIn,
          embedder: _embedder,
          title: 'Register ${employee.name}',
        ),
      ),
    );
    if (!mounted) return;
    if (capture == null || !capture.success || capture.embedding == null) {
      if (capture?.error != null) _snack(capture!.error!);
      return;
    }

    setState(() => _busy = true);
    try {
      final face = await widget.api.registerFace(
        employeeId: employee.id,
        embedding: capture.embedding!,
        modelVersion: FaceEmbedder.modelVersion,
      );
      setState(() => _face = face);
      _snack('Face registered (${face.dimensions} dimensions).');
    } on ApiException catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFace = _face != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Register face')),
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
          if (employees.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No employees found. Ask your administrator to add you '
                  'before registering a face.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  child: Icon(
                    hasFace ? Icons.verified_user : Icons.face,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<Employee>(
                initialValue: _selected,
                decoration: const InputDecoration(
                  labelText: 'Who are you?',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                items: employees
                    .map(
                      (e) => DropdownMenuItem<Employee>(
                        value: e,
                        child: Text(e.name),
                      ),
                    )
                    .toList(),
                onChanged: _busy ? null : _onEmployeeChanged,
              ),
              const SizedBox(height: 20),
              if (_selected != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Face status',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (_checkingFace)
                          const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Checking...'),
                            ],
                          )
                        else if (hasFace) ...[
                          const Text('Registered ✓'),
                          Text('Model: ${_face!.modelVersion}'),
                          Text('Dimensions: ${_face!.dimensions}'),
                        ] else
                          const Text('No face registered yet.'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Capturing opens the camera, detects your face, runs a quick '
                'blink liveness check, then generates a face embedding '
                'on-device. You can register exactly one face. To replace an '
                'existing one, ask your administrator to remove it first.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: (_selected == null ||
                        _checkingFace ||
                        hasFace ||
                        _busy)
                    ? null
                    : _register,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  hasFace ? 'Face already registered' : 'Capture & register face',
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}
