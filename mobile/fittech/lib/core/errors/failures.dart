import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);
  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
  @override
  List<Object?> get props => [message, statusCode];
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(
      [super.message = 'Session expired. Please login again.']);
}

class ValidationFailure extends Failure {
  final Map<String, dynamic>? errors;
  const ValidationFailure(super.message, {this.errors});
  @override
  List<Object?> get props => [message, errors];
}

class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure(
      [super.message = 'Invalid email or password.']);
}

class TokenExpiredFailure extends Failure {
  const TokenExpiredFailure(
      [super.message = 'Your session expired. Please login again.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local storage error.']);
}
