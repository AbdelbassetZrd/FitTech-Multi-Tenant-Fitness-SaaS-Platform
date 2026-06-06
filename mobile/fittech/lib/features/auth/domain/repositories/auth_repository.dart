import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_tokens_entity.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthTokensEntity>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, AuthTokensEntity>> register({
    required String email,
    required String password,
    required String password2,
    required String firstName,
    required String lastName,
    required String phone,
    String role,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, void>> verifyEmail({
    required String email,
    required String code,
  });

  Future<Either<Failure, void>> resendVerification({required String email});

  Future<Either<Failure, String>> refreshToken();

  Future<Either<Failure, UserEntity?>> getCachedUser();

  Future<Either<Failure, UserEntity>> getProfile();

  Future<bool> isLoggedIn();
}
