import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';
import 'base_usecase.dart';

class ResendVerificationUseCase extends UseCase<void, ResendVerificationParams> {
  final AuthRepository _repository;
  ResendVerificationUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(ResendVerificationParams params) {
    return _repository.resendVerification(email: params.email);
  }
}

class ResendVerificationParams extends Equatable {
  final String email;
  const ResendVerificationParams({required this.email});

  @override
  List<Object?> get props => [email];
}
