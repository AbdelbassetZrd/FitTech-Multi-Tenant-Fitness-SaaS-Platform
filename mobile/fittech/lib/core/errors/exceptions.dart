class AppException implements Exception {
  final String message;
  final int? statusCode;
  const AppException(this.message, {this.statusCode});
  @override
  String toString() => 'AppException($statusCode): $message';
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection.']);
}

class ServerException extends AppException {
  final Map<String, dynamic>? body;
  const ServerException(super.message, {super.statusCode, this.body});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized.'])
      : super(statusCode: 401);
}

class ValidationException extends AppException {
  final Map<String, dynamic> errors;
  const ValidationException(super.message, {required this.errors})
      : super(statusCode: 400);
}

class TokenExpiredException extends AppException {
  const TokenExpiredException([super.message = 'Token expired.'])
      : super(statusCode: 401);
}

class CacheException extends AppException {
  const CacheException([super.message = 'Local storage error.']);
}
