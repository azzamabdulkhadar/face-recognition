import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/attendance.dart';
import '../models/employee.dart';
import '../models/face_info.dart';
import '../models/recognition_result.dart';
import 'api_exception.dart';

/// Thin client over the Face Recognition Demo REST API.
///
/// The [baseUrl] should point at the backend host without a trailing slash,
/// e.g. `http://10.0.2.2:5000` for the Android emulator or
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

  Future<Employee> createEmployee({required String name, String? email}) async {
    final body = <String, dynamic>{'name': name};
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }
    final res = await _post('/employees', body);
    return Employee.fromJson(res['employee'] as Map<String, dynamic>);
  }

  Future<void> deleteEmployee(int id) async {
    await _delete('/employees/$id');
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
