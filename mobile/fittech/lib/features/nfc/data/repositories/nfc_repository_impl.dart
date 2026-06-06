import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/access_log_entity.dart';
import '../../domain/entities/access_status_entity.dart';
import '../../domain/repositories/nfc_repository.dart';
import '../datasources/nfc_remote_datasource.dart';

class NfcRepositoryImpl implements NfcRepository {
  final NfcRemoteDataSource remoteDataSource;

  NfcRepositoryImpl({required this.remoteDataSource});

  Either<Failure, T> _mapException<T>(Object e) {
    if (e is UnauthorizedException) return Left(UnauthorizedFailure(e.message));
    if (e is NetworkException) return Left(NetworkFailure(e.message));
    if (e is AppException) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
    return Left(ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, AccessStatusEntity>> getStatus() async {
    try {
      return Right(await remoteDataSource.getStatus());
    } catch (e) {
      return _mapException<AccessStatusEntity>(e);
    }
  }

  @override
  Future<Either<Failure, List<AccessLogEntity>>> getHistory({
    int limit = 20,
  }) async {
    try {
      return Right(await remoteDataSource.getHistory(limit: limit));
    } catch (e) {
      return _mapException<List<AccessLogEntity>>(e);
    }
  }

  @override
  Future<Either<Failure, ScanResultEntity>> simulateScan() async {
    try {
      return Right(await remoteDataSource.simulateScan());
    } catch (e) {
      return _mapException<ScanResultEntity>(e);
    }
  }

  @override
  Future<Either<Failure, String>> registerNfcCard(
      String uid, String deviceType) async {
    try {
      return Right(await remoteDataSource.registerNfcCard(uid, deviceType));
    } catch (e) {
      return _mapException<String>(e);
    }
  }
}
