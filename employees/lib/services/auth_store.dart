import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The authenticated employee returned by login.
class AuthEmployee {
  const AuthEmployee({required this.id, required this.name, this.email});

  final int id;
  final String name;
  final String? email;

  factory AuthEmployee.fromJson(Map<String, dynamic> json) => AuthEmployee(
    id: json['id'] as int,
    name: json['name'] as String? ?? 'Employee',
    email: json['email'] as String?,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

/// Persists the login token and employee across restarts so the user stays
/// signed in. Backed by secure storage.
class AuthStore {
  AuthStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kToken = 'auth.token';
  static const _kEmployee = 'auth.employee';

  String? _token;
  AuthEmployee? _employee;

  String? get token => _token;
  AuthEmployee? get employee => _employee;
  bool get isLoggedIn => _token != null && _employee != null;

  /// Load any saved session into memory. Call once at startup.
  Future<void> load() async {
    _token = await _storage.read(key: _kToken);
    final raw = await _storage.read(key: _kEmployee);
    if (raw != null && raw.isNotEmpty) {
      try {
        _employee = AuthEmployee.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        _employee = null;
      }
    }
  }

  Future<void> save({
    required String token,
    required AuthEmployee employee,
  }) async {
    _token = token;
    _employee = employee;
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kEmployee, value: jsonEncode(employee.toJson()));
  }

  Future<void> clear() async {
    _token = null;
    _employee = null;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kEmployee);
  }
}
