import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'attendance_screen.dart';
import 'register_face_screen.dart';

/// Employee self-service landing screen: face-verified check-in / check-out.
///
/// Reached only after the employee has logged in AND this device is an ACTIVE
/// (admin-approved) device. The authenticated [api] is shared from the app
/// shell so requests carry the login token.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.initialBaseUrl,
    required this.api,
    required this.employeeName,
    required this.onLogout,
  });

  final String initialBaseUrl;
  final ApiClient api;
  final String employeeName;
  final VoidCallback onLogout;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Attendance'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: onLogout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user),
              title: Text(employeeName),
              subtitle: const Text('Signed in · this device is trusted'),
            ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.face_retouching_natural,
            title: 'Register your face',
            subtitle: 'Enroll your face once so attendance can recognize you.',
            onTap: () => _open(context, RegisterFaceScreen(api: api)),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.how_to_reg,
            title: 'Check in / Check out',
            subtitle: 'Record attendance verified by face recognition.',
            onTap: () => _open(context, AttendanceScreen(api: api)),
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
