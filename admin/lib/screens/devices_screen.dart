import 'package:flutter/material.dart';

import '../models/device_info.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';

/// Admin device management: review pending registration requests (approve /
/// reject), manage active devices (revoke / delete), and view the audit log.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device management'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Audit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DeviceList(
            api: widget.api,
            status: DeviceStatus.pendingApproval,
            emptyText: 'No pending device requests.',
          ),
          _DeviceList(
            api: widget.api,
            status: DeviceStatus.active,
            emptyText: 'No active devices.',
          ),
          _AuditList(api: widget.api),
        ],
      ),
    );
  }
}

class _DeviceList extends StatefulWidget {
  const _DeviceList({
    required this.api,
    required this.status,
    required this.emptyText,
  });

  final ApiClient api;
  final DeviceStatus status;
  final String emptyText;

  @override
  State<_DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends State<_DeviceList> {
  late Future<List<DeviceInfo>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listDevices(status: widget.status);
  }

  void _reload() {
    setState(() {
      _future = widget.api.listDevices(status: widget.status);
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _approve(DeviceInfo d) async {
    try {
      await widget.api.approveDevice(d.id);
      _snack('Approved ${d.employeeName ?? 'device'}.');
      _reload();
    } on ApiException catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _reject(DeviceInfo d) async {
    final reason = await _askReason();
    if (reason == null) return;
    try {
      await widget.api.rejectDevice(d.id, reason: reason);
      _snack('Rejected ${d.employeeName ?? 'device'}.');
      _reload();
    } on ApiException catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _revoke(DeviceInfo d) async {
    final ok = await _confirm(
      'Revoke device',
      'Revoke ${d.employeeName ?? 'this employee'}\'s device? They will be '
          'blocked until a new device is approved.',
      'Revoke',
    );
    if (ok != true) return;
    try {
      await widget.api.revokeDevice(d.id);
      _snack('Revoked.');
      _reload();
    } on ApiException catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _delete(DeviceInfo d) async {
    final ok = await _confirm(
      'Delete device',
      'Permanently delete this device record for '
          '${d.employeeName ?? 'the employee'}?',
      'Delete',
    );
    if (ok != true) return;
    try {
      await widget.api.deleteDevice(d.id);
      _snack('Deleted.');
      _reload();
    } on ApiException catch (e) {
      _snack(e.toString());
    }
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject device'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Unknown device',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(String title, String body, String action) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<DeviceInfo>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: FilledButton.tonal(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            );
          }
          final devices = snapshot.data ?? const [];
          if (devices.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(widget.emptyText)),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: devices.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _DeviceTile(
              device: devices[i],
              onApprove: () => _approve(devices[i]),
              onReject: () => _reject(devices[i]),
              onRevoke: () => _revoke(devices[i]),
              onDelete: () => _delete(devices[i]),
            ),
          );
        },
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onApprove,
    required this.onReject,
    required this.onRevoke,
    required this.onDelete,
  });

  final DeviceInfo device;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRevoke;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = device.status == DeviceStatus.pendingApproval;
    final active = device.status == DeviceStatus.active;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smartphone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.employeeName ?? 'Employee #${device.employeeId}',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      device.deviceLabel,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (device.osVersion != null)
                      Text(
                        device.osVersion!,
                        style: theme.textTheme.bodySmall,
                      ),
                    Text(
                      [
                        if (device.platform != null) device.platform,
                        if (device.appVersion != null)
                          'app ${device.appVersion}',
                        if (device.registeredAt != null)
                          'registered ${device.registeredAt}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(device.status.label),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (pending) ...[
                TextButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              ],
              if (active) ...[
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onRevoke,
                  icon: const Icon(Icons.block),
                  label: const Text('Revoke'),
                ),
              ],
              if (!pending && !active)
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditList extends StatefulWidget {
  const _AuditList({required this.api});

  final ApiClient api;

  @override
  State<_AuditList> createState() => _AuditListState();
}

class _AuditListState extends State<_AuditList> {
  late Future<List<DeviceAuditLog>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listDeviceAudit();
  }

  void _reload() {
    setState(() {
      _future = widget.api.listDeviceAudit();
    });
  }

  IconData _iconFor(String action) {
    switch (action) {
      case 'APPROVED':
        return Icons.check_circle_outline;
      case 'REJECTED':
        return Icons.cancel_outlined;
      case 'REVOKED':
        return Icons.block;
      case 'DELETED':
        return Icons.delete_outline;
      case 'RE_REGISTERED':
      case 'REGISTRATION_COMPLETED':
        return Icons.app_registration;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<DeviceAuditLog>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(snapshot.error.toString())),
              ],
            );
          }
          final logs = snapshot.data ?? const [];
          if (logs.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No device activity yet.')),
              ],
            );
          }
          return ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final log = logs[i];
              return ListTile(
                leading: Icon(_iconFor(log.action)),
                title: Text(log.action),
                subtitle: Text(
                  [
                    'by ${log.performedBy}',
                    if (log.employeeId != null) 'employee ${log.employeeId}',
                    if (log.metadata != null && log.metadata!.isNotEmpty)
                      log.metadata,
                    if (log.createdAt != null) log.createdAt,
                  ].join(' · '),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
