import 'package:flutter/material.dart';

import '../models/device.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/auth_store.dart';
import '../services/device_identity.dart';
import 'home_screen.dart';

/// Shown immediately after login. It verifies the current device with the
/// backend and routes to the correct experience:
///   ACTIVE          -> HomeScreen (full access)
///   NOT_REGISTERED  -> register this device
///   PENDING_APPROVAL-> waiting for admin
///   REJECTED        -> register again
///   REVOKED         -> blocked, contact admin
class DeviceGateScreen extends StatefulWidget {
  const DeviceGateScreen({
    super.key,
    required this.api,
    required this.authStore,
    required this.deviceIdentity,
    required this.baseUrl,
    required this.onLogout,
  });

  final ApiClient api;
  final AuthStore authStore;
  final DeviceIdentity deviceIdentity;
  final String baseUrl;
  final VoidCallback onLogout;

  @override
  State<DeviceGateScreen> createState() => _DeviceGateScreenState();
}

class _DeviceGateScreenState extends State<DeviceGateScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  DeviceStatus _status = DeviceStatus.notRegistered;
  DeviceInfo? _device;
  DeviceDetails? _details;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await widget.deviceIdentity.details();
      final result = await widget.api.verifyDevice(details.registrationId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _status = result.status;
        _device = result.device;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // A 401 means the saved token is no longer valid — force a fresh login.
      if (e.statusCode == 401) {
        await _logout();
        return;
      }
      setState(() => _error = e.toString());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final details = _details;
    if (details == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.registerDevice(details);
      await _check();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await widget.authStore.clear();
    widget.api.authToken = null;
    if (mounted) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Approved: hand off to the normal app.
    if (_status == DeviceStatus.active) {
      return HomeScreen(
        initialBaseUrl: widget.baseUrl,
        api: widget.api,
        employeeName: widget.authStore.employee?.name ?? 'Employee',
        onLogout: _logout,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device registration'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _check,
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _busy ? null : _logout,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _body(context),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.authStore.employee?.name ?? 'Employee';
    final deviceLabel = _details?.label ?? _device?.label ?? 'This device';

    final (IconData icon, Color color, String title, String message) info =
        switch (_status) {
          DeviceStatus.notRegistered => (
            Icons.app_registration,
            theme.colorScheme.primary,
            'Register this device',
            'This device is not registered yet. Submit a request and an admin '
                'will approve it before you can record attendance.',
          ),
          DeviceStatus.pendingApproval => (
            Icons.hourglass_top,
            Colors.orange,
            'Waiting for approval',
            'Your request was submitted. An administrator needs to approve '
                'this device before you can continue. Pull to refresh after '
                'approval.',
          ),
          DeviceStatus.rejected => (
            Icons.cancel_outlined,
            theme.colorScheme.error,
            'Registration rejected',
            _device?.rejectionReason != null &&
                    _device!.rejectionReason!.isNotEmpty
                ? 'Your device registration was rejected: '
                      '${_device!.rejectionReason}. You can submit a new '
                      'request.'
                : 'Your device registration was rejected. You can submit a new '
                      'request.',
          ),
          DeviceStatus.revoked => (
            Icons.block,
            theme.colorScheme.error,
            'Device revoked',
            'This device has been revoked by an administrator. Contact your '
                'administrator to use it again.',
          ),
          DeviceStatus.active => (
            Icons.verified,
            Colors.green,
            'Active',
            'This device is trusted.',
          ),
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(info.$1, size: 64, color: info.$2),
        const SizedBox(height: 16),
        Text(info.$3, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          info.$4,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(name),
                subtitle: Text(widget.authStore.employee?.email ?? ''),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.smartphone),
                title: Text(deviceLabel),
                subtitle: Text(
                  _details?.osVersion ?? _device?.osVersion ?? '',
                ),
                trailing: Chip(
                  label: Text(_status.label),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 12),
        ],
        if (_busy) const Center(child: CircularProgressIndicator()),
        if (!_busy &&
            (_status == DeviceStatus.notRegistered ||
                _status == DeviceStatus.rejected))
          FilledButton.icon(
            onPressed: _register,
            icon: const Icon(Icons.app_registration),
            label: Text(
              _status == DeviceStatus.rejected
                  ? 'Register again'
                  : 'Register this device',
            ),
          ),
        if (!_busy && _status == DeviceStatus.pendingApproval)
          FilledButton.tonalIcon(
            onPressed: _check,
            icon: const Icon(Icons.refresh),
            label: const Text('Check status'),
          ),
      ],
    );
  }
}
