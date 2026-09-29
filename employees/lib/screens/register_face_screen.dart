import 'package:flutter/material.dart';

import '../models/employee.dart';
import '../models/face_info.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/face_embedder.dart';
import 'face_capture_screen.dart';

/// Registers or manages the single face allowed per employee.
///
/// A real camera + embedding model will replace the simulated capture here.
class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({
    super.key,
    required this.api,
    required this.employee,
  });

  final ApiClient api;
  final Employee employee;

  @override
  State<RegisterFaceScreen> createState() => _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends State<RegisterFaceScreen> {
  final _embedder = FaceEmbedder();

  FaceInfo? _face;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _embedder.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _face = await widget.api.getFace(widget.employee.id);
    } on ApiException catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _register() async {
    // Open the camera, detect + verify a live face, and get a real embedding.
    final capture = await Navigator.of(context).push<FaceCaptureResult>(
      MaterialPageRoute(
        builder: (_) => FaceCaptureScreen(
          purpose: FaceCapturePurpose.checkIn,
          embedder: _embedder,
          title: 'Register ${widget.employee.name}',
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
        employeeId: widget.employee.id,
        embedding: capture.embedding!,
        modelVersion: FaceEmbedder.modelVersion,
      );
      _changed = true;
      setState(() => _face = face);
      _snack('Face registered (${face.dimensions} dimensions).');
    } on ApiException catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await widget.api.deleteFace(widget.employee.id);
      _changed = true;
      setState(() => _face = null);
      _snack('Registered face removed.');
    } on ApiException catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFace = _face != null;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.employee.name),
          leading: BackButton(
            onPressed: () => Navigator.pop(context, _changed),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Face status',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (hasFace) ...[
                            Text('Registered ✓'),
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
                    'Capturing opens the camera, detects your face, runs a '
                    'quick blink liveness check, then generates a face '
                    'embedding on-device. Each employee can register exactly '
                    'one face.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  if (!hasFace)
                    FilledButton.icon(
                      onPressed: _busy ? null : _register,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture & register face'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove registered face'),
                    ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
      ),
    );
  }
}
