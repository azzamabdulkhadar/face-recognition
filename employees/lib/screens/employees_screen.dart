import 'package:flutter/material.dart';

import '../models/employee.dart';
import '../models/face_info.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import 'register_face_screen.dart';

/// Lists employees, allows creating and deleting them, and shows whether each
/// one has a registered face.
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  late Future<List<Employee>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listEmployees();
  }

  void _reload() {
    setState(() {
      _future = widget.api.listEmployees();
    });
  }

  Future<void> _showError(Object error) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _createEmployee() async {
    final result = await showDialog<_NewEmployee>(
      context: context,
      builder: (_) => const _CreateEmployeeDialog(),
    );
    if (result == null) return;
    try {
      await widget.api.createEmployee(name: result.name, email: result.email);
      _reload();
    } on ApiException catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete employee'),
        content: Text(
          'Delete ${employee.name}? This also removes their registered face.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.api.deleteEmployee(employee.id);
      _reload();
    } on ApiException catch (e) {
      _showError(e);
    }
  }

  Future<void> _openRegister(Employee employee) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegisterFaceScreen(api: widget.api, employee: employee),
      ),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createEmployee,
        icon: const Icon(Icons.person_add),
        label: const Text('New'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Employee>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorView(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }
            final employees = snapshot.data ?? const [];
            if (employees.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text('No employees yet. Tap "New" to add one.'),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: employees.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) => _EmployeeTile(
                api: widget.api,
                employee: employees[i],
                onRegister: () => _openRegister(employees[i]),
                onDelete: () => _deleteEmployee(employees[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmployeeTile extends StatefulWidget {
  const _EmployeeTile({
    required this.api,
    required this.employee,
    required this.onRegister,
    required this.onDelete,
  });

  final ApiClient api;
  final Employee employee;
  final VoidCallback onRegister;
  final VoidCallback onDelete;

  @override
  State<_EmployeeTile> createState() => _EmployeeTileState();
}

class _EmployeeTileState extends State<_EmployeeTile> {
  FaceInfo? _face;
  bool _loadingFace = true;

  @override
  void initState() {
    super.initState();
    _loadFace();
  }

  Future<void> _loadFace() async {
    try {
      final face = await widget.api.getFace(widget.employee.id);
      if (mounted) setState(() => _face = face);
    } catch (_) {
      // Non-fatal: just show "unknown" face status.
    } finally {
      if (mounted) setState(() => _loadingFace = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    final hasFace = _face != null;
    return ListTile(
      leading: CircleAvatar(child: Text(e.name.isNotEmpty ? e.name[0] : '?')),
      title: Text(e.name),
      subtitle: Text(e.email ?? 'No email'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_loadingFace)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(hasFace ? 'Face ✓' : 'No face'),
              backgroundColor: hasFace
                  ? Colors.green.withValues(alpha: 0.15)
                  : null,
            ),
          IconButton(
            tooltip: 'Register / manage face',
            icon: const Icon(Icons.face_retouching_natural),
            onPressed: widget.onRegister,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.cloud_off, size: 48),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(message, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}

class _NewEmployee {
  const _NewEmployee(this.name, this.email);
  final String name;
  final String? email;
}

class _CreateEmployeeDialog extends StatefulWidget {
  const _CreateEmployeeDialog();

  @override
  State<_CreateEmployeeDialog> createState() => _CreateEmployeeDialogState();
}

class _CreateEmployeeDialogState extends State<_CreateEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(context, _NewEmployee(_name.text.trim(), _email.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New employee'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final ok = RegExp(
                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                ).hasMatch(v.trim());
                return ok ? null : 'Invalid email';
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
