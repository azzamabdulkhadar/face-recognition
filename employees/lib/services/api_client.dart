import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/attendance.dart';
import '../models/device.dart';
import '../models/employee.dart';
import '../models/face_info.dart';
import '../services/auth_store.dart';
import '../services/device_identity.dart';
import 'api_exception.dart';

/// Thin client over the Face Recognition Demo REST API, scoped to employee
/// self-service: reading the employee directory (for names in history) and
/// recording face-verified check-in / check-out events.
///
/// The [baseUrl] should point at the backend host without a trailing slash,
/// e.g. `http://192.168.1.40:5000` for the Android emulator or
/// `http://localhost:5000` for web/desktop.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client, this.authToken})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// JWT attached as `Authorization: Bearer` to every request when present.
  String? authToken;

  Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (authToken != null && authToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $authToken';
    }
    return h;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl/api$path');

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// Log in with email + password. On success the returned token is also
  /// applied to this client for subsequent requests.
  Future<({String token, AuthEmployee employee})> login({
    required String email,
    required String password,
  }) async {
    final res = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    final token = res['token'] as String;
    final employee = AuthEmployee.fromJson(
      res['employee'] as Map<String, dynamic>,
    );
    authToken = token;
    return (token: token, employee: employee);
  }

  // ---------------------------------------------------------------------------
  // Devices
  // ---------------------------------------------------------------------------

  /// Ask the backend for this device's trust status (called after login).
  Future<({DeviceStatus status, DeviceInfo? device})> verifyDevice(
    String deviceRegistrationId,
  ) async {
    final res = await _post('/devices/verify', {
      'deviceRegistrationId': deviceRegistrationId,
    });
    final deviceJson = res['device'];
    return (
      status: DeviceStatus.fromWire(res['status'] as String?),
      device: deviceJson == null
          ? null
          : DeviceInfo.fromJson(deviceJson as Map<String, dynamic>),
    );
  }

  /// Submit (or re-submit) the current device for admin approval.
  Future<DeviceInfo> registerDevice(DeviceDetails details) async {
    final res = await _post('/devices/register', {
      'deviceRegistrationId': details.registrationId,
      if (details.platform != null) 'platform': details.platform,
      if (details.model != null) 'deviceModel': details.model,
      if (details.manufacturer != null) 'manufacturer': details.manufacturer,
      if (details.osVersion != null) 'osVersion': details.osVersion,
      if (details.appVersion != null) 'appVersion': details.appVersion,
    });
    return DeviceInfo.fromJson(res['device'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Employees (read-only: used to label attendance history with names)
  // ---------------------------------------------------------------------------

  Future<List<Employee>> listEmployees() async {
    final res = await _get('/employees');
    final list = (res['employees'] as List<dynamic>? ?? const []);
    return list
        .map((e) => Employee.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Faces (self-service registration: one face per employee)
  // ---------------------------------------------------------------------------

  /// Register a face [embedding] for [employeeId].
  ///
  /// Throws an [ApiException] with status 404 when the employee does not exist,
  /// or 409 when the employee already has a registered face.
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

  // ---------------------------------------------------------------------------
  // Attendance (face-verified check-in / check-out)
  // ---------------------------------------------------------------------------

  /// Verify a face by its [embedding] and record a check-in / check-out.
  ///
  /// Throws an [ApiException] with status 401 when the face is not recognized,
  /// or 409 when the requested transition is invalid (e.g. checking in twice).
  Future<AttendanceRecord> recordAttendance({
    required List<double> embedding,
    required AttendanceEventType event,
  }) async {
    final res = await _post('/attendance', {
      'embedding': embedding,
      'event': event.wire,
    });
    return AttendanceRecord.fromJson(res);
  }

  Future<AttendanceStatus> getAttendanceStatus(int employeeId) async {
    final res = await _get('/attendance/$employeeId/status');
    return AttendanceStatus.fromJson(res);
  }

  Future<List<AttendanceEntry>> listAttendance({
    int? employeeId,
    int? limit,
  }) async {
    final params = <String, String>{};
    if (employeeId != null) params['employeeId'] = '$employeeId';
    if (limit != null) params['limit'] = '$limit';
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final res = await _get('/attendance$query');
    final list = (res['events'] as List<dynamic>? ?? const []);
    return list
        .map((e) => AttendanceEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // HTTP helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _get(String path) =>
      _send(() => _client.get(_uri(path), headers: _headers));

  Future<Map<String, dynamic>> _post(String path, Object body) => _send(
    () => _client.post(_uri(path), headers: _headers, body: jsonEncode(body)),
  );

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
