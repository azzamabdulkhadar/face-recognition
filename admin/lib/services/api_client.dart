import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/device_info.dart';
import '../models/employee.dart';
import '../models/face_info.dart';
import '../models/recognition_result.dart';
import 'api_exception.dart';

/// Thin client over the Face Recognition Demo REST API, scoped to the admin
/// surface: employee management, face registration, and recognition testing.
///
/// The [baseUrl] should point at the backend host without a trailing slash,
/// e.g. `http://192.168.1.40:5000` for the Android emulator or
/// `http://localhost:5000` for web/desktop.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  Uri _uri(String path) => Uri.parse('$baseUrl/api$path');

  // ---------------------------------------------------------------------------
  // Employees
  // ---------------------------------------------------------------------------

  Future<List<Employee>> listEmployees() async {
    final res = await _get('/employees');
    final list = (res['employees'] as List<dynamic>? ?? const []);
    return list
        .map((e) => Employee.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Employee> createEmployee({
    required String name,
    String? email,
    String? password,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }
    final res = await _post('/employees', body);
    return Employee.fromJson(res['employee'] as Map<String, dynamic>);
  }

  Future<void> deleteEmployee(int id) async {
    await _delete('/employees/$id');
  }

  /// Set or reset an employee's login password.
  Future<void> setEmployeePassword(int id, String password) async {
    await _post('/employees/$id/password', {'password': password});
  }

  // ---------------------------------------------------------------------------
  // Devices (admin management: approve / reject / revoke / delete)
  // ---------------------------------------------------------------------------

  /// All device registrations, optionally filtered by status.
  Future<List<DeviceInfo>> listDevices({DeviceStatus? status}) async {
    final query = status == null ? '' : '?status=${_statusWire(status)}';
    final res = await _get('/devices$query');
    final list = (res['devices'] as List<dynamic>? ?? const []);
    return list
        .map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<DeviceInfo> approveDevice(int deviceId) async {
    final res = await _post('/devices/$deviceId/approve', const {});
    return DeviceInfo.fromJson(res['device'] as Map<String, dynamic>);
  }

  Future<DeviceInfo> rejectDevice(int deviceId, {String? reason}) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
    }
    final res = await _post('/devices/$deviceId/reject', body);
    return DeviceInfo.fromJson(res['device'] as Map<String, dynamic>);
  }

  Future<DeviceInfo> revokeDevice(int deviceId) async {
    final res = await _post('/devices/$deviceId/revoke', const {});
    return DeviceInfo.fromJson(res['device'] as Map<String, dynamic>);
  }

  Future<void> deleteDevice(int deviceId) async {
    await _delete('/devices/$deviceId');
  }

  Future<List<DeviceAuditLog>> listDeviceAudit() async {
    final res = await _get('/devices/audit');
    final list = (res['logs'] as List<dynamic>? ?? const []);
    return list
        .map((e) => DeviceAuditLog.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static String _statusWire(DeviceStatus s) {
    switch (s) {
      case DeviceStatus.pendingApproval:
        return 'PENDING_APPROVAL';
      case DeviceStatus.active:
        return 'ACTIVE';
      case DeviceStatus.rejected:
        return 'REJECTED';
      case DeviceStatus.revoked:
        return 'REVOKED';
    }
  }

  // ---------------------------------------------------------------------------
  // Faces
  // ---------------------------------------------------------------------------

  Future<FaceInfo> registerFace({
    required int employeeId,
    required List<double> embedding,
    String? modelVersion,
  }) async {
    final body = <String, dynamic>{
      'employeeId': employeeId,
      'embedding': embedding,
    };
    if (modelVersion != null && modelVersion.isNotEmpty) {
      body['modelVersion'] = modelVersion;
    }
    final res = await _post('/faces/register', body);
    return FaceInfo.fromJson(res['face'] as Map<String, dynamic>);
  }

  Future<RecognitionResult> recognizeFace(List<double> embedding) async {
    final res = await _post('/faces/recognize', {'embedding': embedding});
    return RecognitionResult.fromJson(res);
  }

  /// Returns the registered face for an employee, or `null` if none exists.
  Future<FaceInfo?> getFace(int employeeId) async {
    try {
      final res = await _get('/faces/$employeeId');
      return FaceInfo.fromJson(res['face'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> deleteFace(int employeeId) async {
    await _delete('/faces/$employeeId');
  }

  // ---------------------------------------------------------------------------
  // HTTP helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _get(String path) =>
      _send(() => _client.get(_uri(path), headers: _jsonHeaders));

  Future<Map<String, dynamic>> _post(String path, Object body) => _send(
    () =>
        _client.post(_uri(path), headers: _jsonHeaders, body: jsonEncode(body)),
  );

  Future<Map<String, dynamic>> _delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: _jsonHeaders));

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    http.Response res;
    try {
      res = await request();
    } catch (e) {
      throw ApiException('Could not reach the server. $e');
    }

    Map<String, dynamic> json;
    try {
      json = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Unexpected response from server (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message =
          json['message'] as String? ??
          'Request failed with status ${res.statusCode}';
      throw ApiException(message, statusCode: res.statusCode);
    }

    return json;
  }

  void dispose() => _client.close();
}
