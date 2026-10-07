import 'package:flutter/material.dart';

import 'config.dart';
import 'screens/device_gate_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_store.dart';
import 'services/device_identity.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authStore = AuthStore();
  await authStore.load();
  runApp(FaceRecognitionApp(authStore: authStore));
}

class FaceRecognitionApp extends StatelessWidget {
  const FaceRecognitionApp({super.key, required this.authStore});

  final AuthStore authStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Employee Attendance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: AppShell(authStore: authStore),
    );
  }
}

/// Owns the backend URL and the shared [ApiClient], and switches between the
/// login screen and the device gate based on whether a session exists.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.authStore});

  final AuthStore authStore;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _deviceIdentity = DeviceIdentity();

  late String _baseUrl = defaultBaseUrl();
  late ApiClient _api = ApiClient(
    baseUrl: _baseUrl,
    authToken: widget.authStore.token,
  );

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _editBaseUrl() async {
    final controller = TextEditingController(text: _baseUrl);
    final newUrl = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backend URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'http://10.0.2.2:5000'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newUrl == null || newUrl.isEmpty || newUrl == _baseUrl) return;
    final old = _api;
    setState(() {
      _baseUrl = newUrl.endsWith('/')
          ? newUrl.substring(0, newUrl.length - 1)
          : newUrl;
      _api = ApiClient(baseUrl: _baseUrl, authToken: widget.authStore.token);
    });
    old.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.authStore.isLoggedIn) {
      return LoginScreen(
        api: _api,
        authStore: widget.authStore,
        baseUrl: _baseUrl,
        onEditBaseUrl: _editBaseUrl,
        onLoggedIn: () => setState(() {}),
      );
    }
    return DeviceGateScreen(
      // Keyed by token so a fresh login rebuilds the gate from scratch.
      key: ValueKey(widget.authStore.token),
      api: _api,
      authStore: widget.authStore,
      deviceIdentity: _deviceIdentity,
      baseUrl: _baseUrl,
      onLogout: () => setState(() {}),
    );
  }
}
