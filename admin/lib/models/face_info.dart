/// Metadata about a registered face, returned by the backend.
class FaceInfo {
  final int id;
  final int employeeId;
  final String modelVersion;
  final int dimensions;
  final String? createdAt;
  final String? updatedAt;

  const FaceInfo({
    required this.id,
    required this.employeeId,
    required this.modelVersion,
    required this.dimensions,
    this.createdAt,
    this.updatedAt,
  });

  factory FaceInfo.fromJson(Map<String, dynamic> json) {
    return FaceInfo(
      id: json['id'] as int,
      employeeId: json['employeeId'] as int,
      modelVersion: json['modelVersion'] as String,
      dimensions: json['dimensions'] as int,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}
