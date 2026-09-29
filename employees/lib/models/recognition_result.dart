/// Result of a face recognition request.
class RecognitionResult {
  final bool matched;
  final int? employeeId;
  final String? employeeName;
  final double? similarity;

  const RecognitionResult({
    required this.matched,
    this.employeeId,
    this.employeeName,
    this.similarity,
  });

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] as Map<String, dynamic>?;
    final rawSimilarity = json['similarity'];
    return RecognitionResult(
      matched: json['matched'] as bool? ?? false,
      employeeId: employee?['id'] as int?,
      employeeName: employee?['name'] as String?,
      similarity: rawSimilarity == null
          ? null
          : (rawSimilarity as num).toDouble(),
    );
  }
}
