import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_tokens_entity.dart';
import '../repositories/auth_repository.dart';
import 'base_usecase.dart';

class RegisterUseCase extends UseCase<AuthTokensEntity, RegisterParams> {
  final AuthRepository _repository;
  RegisterUseCase(this._repository);

  @override
  Future<Either<Failure, AuthTokensEntity>> call(RegisterParams params) {
    return _repository.register(
      email: params.email,
      password: params.password,
      password2: params.password2,
      firstName: params.firstName,
      lastName: params.lastName,
      phone: params.phone,
      role: params.role,
    );
  }
}

class RegisterParams extends Equatable {
  final String email;
  final String password;
  final String password2;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;

  const RegisterParams({
    required this.email,
    required this.password,
    required this.password2,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.role = 'member',
  });

  @override
  List<Object?> get props =>
      [email, password, password2, firstName, lastName, phone, role];
}
