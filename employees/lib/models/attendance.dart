/// The two kinds of attendance events.
enum AttendanceEventType {
  checkIn,
  checkOut;

  /// Wire value expected by the backend.
  String get wire =>
      this == AttendanceEventType.checkIn ? 'check_in' : 'check_out';

  static AttendanceEventType fromWire(String value) => value == 'check_in'
      ? AttendanceEventType.checkIn
      : AttendanceEventType.checkOut;

  String get label =>
      this == AttendanceEventType.checkIn ? 'Check in' : 'Check out';
}

/// Result of a successful face-verified check-in / check-out.
class AttendanceRecord {
  final AttendanceEventType event;
  final int employeeId;
  final String employeeName;
  final double? similarity;
  final String? recordedAt;

  const AttendanceRecord({
    required this.event,
    required this.employeeId,
    required this.employeeName,
    this.similarity,
    this.recordedAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] as Map<String, dynamic>?;
    final rawSimilarity = json['similarity'];
    return AttendanceRecord(
      event: AttendanceEventType.fromWire(
        json['event'] as String? ?? 'check_in',
      ),
      employeeId:
          (employee?['id'] as int?) ?? (json['employeeId'] as int? ?? 0),
      employeeName: (employee?['name'] as String?) ?? 'Employee',
      similarity: rawSimilarity == null
          ? null
          : (rawSimilarity as num).toDouble(),
      recordedAt: json['recordedAt'] as String?,
    );
  }
}

/// Current check-in state for an employee.
class AttendanceStatus {
  final int employeeId;
  final bool checkedIn;
  final String? since;

  const AttendanceStatus({
    required this.employeeId,
    required this.checkedIn,
    this.since,
  });

  factory AttendanceStatus.fromJson(Map<String, dynamic> json) {
    return AttendanceStatus(
      employeeId: json['employeeId'] as int,
      checkedIn: (json['status'] as String?) == 'checked_in',
      since: json['since'] as String?,
    );
  }
}

/// A single attendance history entry.
class AttendanceEntry {
  final int id;
  final int employeeId;
  final AttendanceEventType event;
  final double? similarity;
  final String? recordedAt;

  const AttendanceEntry({
    required this.id,
    required this.employeeId,
    required this.event,
    this.similarity,
    this.recordedAt,
  });

  factory AttendanceEntry.fromJson(Map<String, dynamic> json) {
    final rawSimilarity = json['similarity'];
    return AttendanceEntry(
      id: json['id'] as int,
      employeeId: json['employeeId'] as int,
      event: AttendanceEventType.fromWire(
        json['event'] as String? ?? 'check_in',
      ),
      similarity: rawSimilarity == null
          ? null
          : (rawSimilarity as num).toDouble(),
      recordedAt: json['recordedAt'] as String?,
    );
  }
}
