import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/access_log_entity.dart';
import '../entities/access_status_entity.dart';

abstract class NfcRepository {
  Future<Either<Failure, AccessStatusEntity>> getStatus();
  Future<Either<Failure, List<AccessLogEntity>>> getHistory({int limit = 20});
  Future<Either<Failure, ScanResultEntity>> simulateScan();
  Future<Either<Failure, String>> registerNfcCard(
      String uid, String deviceType);
}
