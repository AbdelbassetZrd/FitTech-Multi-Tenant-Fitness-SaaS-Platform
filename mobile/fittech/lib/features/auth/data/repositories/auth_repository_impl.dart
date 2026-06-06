import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_tokens_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;

  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required TokenStorage tokenStorage,
  })  : _remote = remoteDataSource,
        _storage = tokenStorage;

  // ── Login ──────────────────────────────────────────────────────────────────
  @override
  Future<Either<Failure, AuthTokensEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _remote.login(email: email, password: password);
      await _storage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      if (response.user != null) {
        await _storage.saveUser(response.user!.toJson());
      }
      return Right(response.toEntity());
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message, errors: e.errors));
    } on UnauthorizedException catch (e) {
      return Left(InvalidCredentialsFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────
  @override
  Future<Either<Failure, AuthTokensEntity>> register({
    required String email,
    required String password,
    required String password2,
    required String firstName,
    required String lastName,
    required String phone,
    String role = 'member',
  }) async {
    try {
      final response = await _remote.register(
        email: email,
        password: password,
        password2: password2,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        role: role,
      );
      await _storage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      if (response.user != null) {
        await _storage.saveUser(response.user!.toJson());
      }
      return Right(response.toEntity());
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message, errors: e.errors));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _remote.logout();
    } catch (_) {
      // Clear local data even if remote call fails
    } finally {
      await _storage.clearAll();
    }
    return const Right(null);
  }

  // ── Verify Email ───────────────────────────────────────────────────────────
  @override
  Future<Either<Failure, void>> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _remote.verifyEmail(email: email, code: code);
      if (response.accessToken.isNotEmpty && response.refreshToken.isNotEmpty) {
        await _storage.saveTokens(
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
        );
      }
      if (response.user != null) {
        await _storage.saveUser(response.user!.toJson());
      }
      return const Right(null);
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message, errors: e.errors));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Resend Verification ────────────────────────────────────────────────────
  @override
  Future<Either<Failure, void>> resendVerification({
    required String email,
  }) async {
    try {
      await _remote.resendVerification(email: email);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Refresh Token ──────────────────────────────────────────────────────────
  @override
  Future<Either<Failure, String>> refreshToken() async {
    try {
      final refresh = await _storage.getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        return const Left(TokenExpiredFailure());
      }
      final newAccess = await _remote.refreshToken(refresh: refresh);
      await _storage.saveAccessToken(newAccess);
      return Right(newAccess);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(TokenExpiredFailure(e.toString()));
    }
  }

  // ── Get Cached User ────────────────────────────────────────────────────────
  @override
  Future<Either<Failure, UserEntity?>> getCachedUser() async {
    try {
      final userMap = await _storage.getUser();
      if (userMap == null) return const Right(null);
      return Right(UserEntity.fromJson(userMap));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getProfile() async {
    try {
      final user = await _remote.getProfile();
      await _storage.saveUser(user.toJson());
      return Right(user);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── Is Logged In ───────────────────────────────────────────────────────────
  @override
  Future<bool> isLoggedIn() => _storage.isLoggedIn();
}
