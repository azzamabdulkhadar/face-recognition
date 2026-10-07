/// Error raised when the backend returns a non-success response
/// or the request fails at the transport level.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
