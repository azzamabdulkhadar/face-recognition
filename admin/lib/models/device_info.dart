/// Device registration status.
enum DeviceStatus {
  pendingApproval,
  active,
  rejected,
  revoked;

  static DeviceStatus fromWire(String? value) {
    switch (value) {
      case 'ACTIVE':
        return DeviceStatus.active;
      case 'REJECTED':
        return DeviceStatus.rejected;
      case 'REVOKED':
        return DeviceStatus.revoked;
      default:
        return DeviceStatus.pendingApproval;
    }
  }

  String get label {
    switch (this) {
      case DeviceStatus.pendingApproval:
        return 'Pending';
      case DeviceStatus.active:
        return 'Active';
      case DeviceStatus.rejected:
        return 'Rejected';
      case DeviceStatus.revoked:
        return 'Revoked';
    }
  }
}

/// A device registration record, as seen by the admin (includes employeeName).
class DeviceInfo {
  final int id;
  final int employeeId;
  final String? employeeName;
  final String deviceRegistrationId;
  final String? platform;
  final String? deviceModel;
  final String? manufacturer;
  final String? osVersion;
  final String? appVersion;
  final DeviceStatus status;
  final String? rejectionReason;
  final String? registeredAt;
  final String? approvedAt;
  final String? lastUsedAt;

  const DeviceInfo({
    required this.id,
    required this.employeeId,
    required this.deviceRegistrationId,
    required this.status,
    this.employeeName,
    this.platform,
    this.deviceModel,
    this.manufacturer,
    this.osVersion,
    this.appVersion,
    this.rejectionReason,
    this.registeredAt,
    this.approvedAt,
    this.lastUsedAt,
  });

  String get deviceLabel {
    final parts = [
      manufacturer,
      deviceModel,
    ].where((p) => p != null && p.isNotEmpty);
    if (parts.isEmpty) return platform ?? 'Device';
    return parts.join(' ');
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as int,
      employeeId: json['employeeId'] as int,
      employeeName: json['employeeName'] as String?,
      deviceRegistrationId: json['deviceRegistrationId'] as String? ?? '',
      platform: json['platform'] as String?,
      deviceModel: json['deviceModel'] as String?,
      manufacturer: json['manufacturer'] as String?,
      osVersion: json['osVersion'] as String?,
      appVersion: json['appVersion'] as String?,
      status: DeviceStatus.fromWire(json['status'] as String?),
      rejectionReason: json['rejectionReason'] as String?,
      registeredAt: json['registeredAt'] as String?,
      approvedAt: json['approvedAt'] as String?,
      lastUsedAt: json['lastUsedAt'] as String?,
    );
  }
}

/// A device audit-log entry.
class DeviceAuditLog {
  final int id;
  final int? deviceId;
  final int? employeeId;
  final String action;
  final String performedBy;
  final String? metadata;
  final String? createdAt;

  const DeviceAuditLog({
    required this.id,
    required this.action,
    required this.performedBy,
    this.deviceId,
    this.employeeId,
    this.metadata,
    this.createdAt,
  });

  factory DeviceAuditLog.fromJson(Map<String, dynamic> json) {
    return DeviceAuditLog(
      id: json['id'] as int,
      deviceId: json['device_id'] as int?,
      employeeId: json['employee_id'] as int?,
      action: json['action'] as String? ?? '',
      performedBy: json['performed_by'] as String? ?? 'system',
      metadata: json['metadata'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
