/// Trust status of a device for the current employee.
enum DeviceStatus {
  notRegistered,
  pendingApproval,
  active,
  rejected,
  revoked;

  static DeviceStatus fromWire(String? value) {
    switch (value) {
      case 'PENDING_APPROVAL':
        return DeviceStatus.pendingApproval;
      case 'ACTIVE':
        return DeviceStatus.active;
      case 'REJECTED':
        return DeviceStatus.rejected;
      case 'REVOKED':
        return DeviceStatus.revoked;
      default:
        return DeviceStatus.notRegistered;
    }
  }

  String get label {
    switch (this) {
      case DeviceStatus.notRegistered:
        return 'Not registered';
      case DeviceStatus.pendingApproval:
        return 'Pending approval';
      case DeviceStatus.active:
        return 'Active';
      case DeviceStatus.rejected:
        return 'Rejected';
      case DeviceStatus.revoked:
        return 'Revoked';
    }
  }
}

/// A device registration record returned by the backend.
class DeviceInfo {
  final int id;
  final int employeeId;
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

  String get label {
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
