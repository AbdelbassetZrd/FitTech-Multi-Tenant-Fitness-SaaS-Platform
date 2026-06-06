import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';
import 'base_usecase.dart';

class VerifyEmailUseCase extends UseCase<void, VerifyEmailParams> {
  final AuthRepository _repository;
  VerifyEmailUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(VerifyEmailParams params) {
    return _repository.verifyEmail(email: params.email, code: params.code);
  }
}

class VerifyEmailParams extends Equatable {
  final String email;
  final String code;
  const VerifyEmailParams({required this.email, required this.code});

  @override
  List<Object?> get props => [email, code];
}
