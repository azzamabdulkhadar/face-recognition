import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'attendance_screen.dart';
import 'employees_screen.dart';
import 'recognize_screen.dart';

/// Landing screen with the two main flows and a place to configure the
/// backend URL.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.initialBaseUrl});

  final String initialBaseUrl;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _baseUrl = widget.initialBaseUrl;
  late ApiClient _api = ApiClient(baseUrl: _baseUrl);

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
      _api = ApiClient(baseUrl: _baseUrl);
    });
    old.dispose();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition Demo'),
        actions: [
          IconButton(
            tooltip: 'Backend URL',
            icon: const Icon(Icons.settings),
            onPressed: _editBaseUrl,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Backend'),
              subtitle: Text(_baseUrl),
              trailing: const Icon(Icons.edit),
              onTap: _editBaseUrl,
            ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.people,
            title: 'Employees',
            subtitle: 'Create, view, and delete employees. Register a face.',
            onTap: () => _open(EmployeesScreen(api: _api)),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.center_focus_strong,
            title: 'Recognize',
            subtitle: 'Simulate a capture and identify the employee.',
            onTap: () => _open(RecognizeScreen(api: _api)),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.how_to_reg,
            title: 'Check in / Check out',
            subtitle: 'Record attendance verified by face recognition.',
            onTap: () => _open(AttendanceScreen(api: _api)),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
