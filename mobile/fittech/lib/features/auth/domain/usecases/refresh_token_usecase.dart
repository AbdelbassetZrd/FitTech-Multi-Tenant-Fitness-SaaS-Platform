import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';
import 'base_usecase.dart';

class RefreshTokenUseCase extends UseCase<String, NoParams> {
  final AuthRepository _repository;
  RefreshTokenUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(NoParams params) {
    return _repository.refreshToken();
  }
}
