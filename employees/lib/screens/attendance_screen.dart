import 'dart:async';

import 'package:flutter/material.dart';

import '../models/attendance.dart';
import '../models/employee.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/face_embedder.dart';
import 'face_capture_screen.dart';

/// Face-verified check-in / check-out.
///
/// Tapping check in / out opens the camera, verifies a live face, generates a
/// real embedding on-device, and sends it to /api/attendance. The backend
/// recognizes the person from the embedding and records the event only when it
/// matches a registered face.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _embedder = FaceEmbedder();

  late Future<List<Employee>> _employeesFuture;
  bool _busy = false;
  AttendanceRecord? _result;
  String? _error;
  List<AttendanceEntry> _history = const [];

  // Current session for the employee who last checked in/out on this device.
  String? _sessionEmployeeName;
  DateTime? _checkInAt;
  DateTime? _checkOutAt;
  Timer? _ticker;

  bool get _shiftActive => _checkInAt != null && _checkOutAt == null;

  @override
  void initState() {
    super.initState();
    _employeesFuture = widget.api.listEmployees();
    _loadHistory();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _embedder.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final events = await widget.api.listAttendance(limit: 20);
      if (mounted) setState(() => _history = events);
    } catch (_) {
      // History is non-critical; ignore failures here.
    }
  }

  /// Derive the current session (latest check-in and its matching check-out)
  /// for [employeeId] from the backend, and keep the duration ticking.
  Future<void> _refreshSession(int employeeId, String employeeName) async {
    try {
      final events = await widget.api.listAttendance(
        employeeId: employeeId,
        limit: 20,
      );
      // events are newest-first. Find the most recent check-in, then the most
      // recent check-out that happened after it (if any).
      AttendanceEntry? lastCheckIn;
      for (final e in events) {
        if (e.event == AttendanceEventType.checkIn) {
          lastCheckIn = e;
          break;
        }
      }
      DateTime? inAt;
      DateTime? outAt;
      if (lastCheckIn != null) {
        inAt = _parse(lastCheckIn.recordedAt);
        // A check-out counts for this session only if it is newer than the
        // check-in (events are newest-first, so it appears before it in list).
        for (final e in events) {
          if (e.event == AttendanceEventType.checkOut) {
            final t = _parse(e.recordedAt);
            if (t != null && inAt != null && t.isAfter(inAt)) {
              outAt = t;
              break;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _sessionEmployeeName = employeeName;
        _checkInAt = inAt;
        _checkOutAt = outAt;
      });
      _syncTicker();
    } catch (_) {
      // Session summary is best-effort.
    }
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (_shiftActive) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  DateTime? _parse(String? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> _submit(AttendanceEventType event) async {
    setState(() {
      _result = null;
      _error = null;
    });

    // Open the camera and require a live, single, verified face before we
    // record anything. If verification fails or is cancelled, nothing is sent.
    final capture = await Navigator.of(context).push<FaceCaptureResult>(
      MaterialPageRoute(
        builder: (_) => FaceCaptureScreen(
          purpose: event == AttendanceEventType.checkIn
              ? FaceCapturePurpose.checkIn
              : FaceCapturePurpose.checkOut,
          embedder: _embedder,
        ),
      ),
    );
    if (!mounted) return;
    if (capture == null || !capture.success || capture.embedding == null) {
      setState(
        () => _error =
            capture?.error ?? 'Face not verified. Attendance not recorded.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });
    try {
      final record = await widget.api.recordAttendance(
        embedding: capture.embedding!,
        event: event,
      );
      setState(() => _result = record);
      await _refreshSession(record.employeeId, record.employeeName);
      await _loadHistory();
    } on ApiException catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check in / Check out')),
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
              if (_checkInAt != null) ...[
                _SessionSummary(
                  employeeName: _sessionEmployeeName,
                  shiftActive: _shiftActive,
                  checkInAt: _checkInAt,
                  checkOutAt: _checkOutAt,
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'Tap Check in or Check out to open the camera. Your face is '
                'detected live and must pass a quick blink liveness check, then '
                'an embedding is generated on-device and matched against '
                'registered faces. The event is recorded only when your face '
                'is recognized.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _submit(AttendanceEventType.checkIn),
                      icon: const Icon(Icons.camera_front),
                      label: const Text('Check in'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => _submit(AttendanceEventType.checkOut),
                      icon: const Icon(Icons.camera_front),
                      label: const Text('Check out'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_busy) const Center(child: CircularProgressIndicator()),
              if (_error != null) _ResultCard.error(_error!),
              if (_result != null) _ResultCard.forRecord(_result!),
              const SizedBox(height: 24),
              Text(
                'Recent activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No attendance events yet.'),
                )
              else
                ..._history.map(
                  (e) => _HistoryTile(entry: e, employees: employees),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Top-of-screen summary: status pill, live Active Duration, and the CHECK IN /
/// CHECK OUT time cards, mirroring the reference design.
class _SessionSummary extends StatelessWidget {
  const _SessionSummary({
    required this.employeeName,
    required this.shiftActive,
    required this.checkInAt,
    required this.checkOutAt,
  });

  final String? employeeName;
  final bool shiftActive;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = shiftActive ? Colors.teal : Colors.blueGrey;

    // Duration = (checkOut ?? now) - checkIn.
    final end = checkOutAt ?? DateTime.now();
    final elapsed = (checkInAt == null || end.isBefore(checkInAt!))
        ? Duration.zero
        : end.difference(checkInAt!);

    return Column(
      children: [
        if (employeeName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              employeeName!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: accent.shade700,
              ),
            ),
          ),
        // Status pill.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                shiftActive ? Icons.access_time_filled : Icons.event_available,
                size: 18,
                color: accent.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                shiftActive ? 'Shift Active' : 'Shift Ended',
                style: TextStyle(
                  color: accent.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Big active duration.
        Text(
          _formatDuration(elapsed),
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [],
          ),
        ),
        Text(
          shiftActive ? 'Active Duration' : 'Total Duration',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        // Check in / check out time cards.
        Row(
          children: [
            Expanded(
              child: _TimeCard(
                icon: Icons.login,
                label: 'CHECK IN',
                time: checkInAt,
                accent: Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeCard(
                icon: Icons.logout,
                label: 'CHECK OUT',
                time: checkOutAt,
                accent: Colors.blueGrey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }
}

/// A single "CHECK IN" / "CHECK OUT" card showing the time (or --/-- when
/// there is no event yet).
class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.icon,
    required this.label,
    required this.time,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final DateTime? time;
  final MaterialColor accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: accent.shade700),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _timeText(theme),
          ],
        ),
      ),
    );
  }

  Widget _timeText(ThemeData theme) {
    if (time == null) {
      return Text(
        '--/--',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.outline,
        ),
      );
    }
    final t = time!;
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final period = t.hour < 12 ? 'AM' : 'PM';
    final minute = t.minute.toString().padLeft(2, '0');
    return RichText(
      text: TextSpan(
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        children: [
          TextSpan(text: '$hour12:$minute'),
          TextSpan(
            text: ' $period',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.employees});

  final AttendanceEntry entry;
  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    final isIn = entry.event == AttendanceEventType.checkIn;
    final matches = employees.where((e) => e.id == entry.employeeId);
    final name = matches.isEmpty ? null : matches.first.name;
    return ListTile(
      dense: true,
      leading: Icon(
        isIn ? Icons.login : Icons.logout,
        color: isIn ? Colors.green : Colors.blueGrey,
      ),
      title: Text(name ?? 'Employee ${entry.employeeId}'),
      subtitle: Text(entry.event.label),
      trailing: Text(
        _formatTime(entry.recordedAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  String _formatTime(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
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

  factory _ResultCard.forRecord(AttendanceRecord r) {
    final isIn = r.event == AttendanceEventType.checkIn;
    return _ResultCard(
      color: isIn ? Colors.green : Colors.indigo,
      icon: isIn ? Icons.login : Icons.logout,
      title: '${r.employeeName} ${isIn ? 'checked in' : 'checked out'}',
      detail: r.similarity == null
          ? 'Face verified.'
          : 'Face verified — similarity ${r.similarity!.toStringAsFixed(4)}',
    );
  }

  factory _ResultCard.error(String message) => _ResultCard(
    color: Colors.red,
    icon: Icons.error_outline,
    title: 'Not recorded',
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
