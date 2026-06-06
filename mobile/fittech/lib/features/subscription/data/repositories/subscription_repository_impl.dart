import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/subscription_entity.dart';
import '../datasources/subscription_remote_datasource.dart';

class SubscriptionRepository {
  final SubscriptionRemoteDataSource remoteDataSource;

  SubscriptionRepository({required this.remoteDataSource});

  Future<Either<Failure, List<SubscriptionPlanEntity>>>
      getSubscriptionPlans() async {
    try {
      final result = await remoteDataSource.getSubscriptionPlans();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  Future<Either<Failure, PaymentInitiationEntity>> initiateChargilyPayment(
      int planId) async {
    try {
      final result = await remoteDataSource.initiateChargilyPayment(planId);
      return Right(result);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on TokenExpiredException catch (e) {
      return Left(TokenExpiredFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  Future<Either<Failure, SubscriptionStatusEntity>> verifyChargilyPayment({
    required String transactionId,
    required int paymentId,
  }) async {
    try {
      final result = await remoteDataSource.verifyChargilyPayment(
        transactionId: transactionId,
        paymentId: paymentId,
      );
      return Right(result);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on TokenExpiredException catch (e) {
      return Left(TokenExpiredFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  Future<Either<Failure, SubscriptionStatusEntity>>
      checkSubscriptionStatus() async {
    try {
      final result = await remoteDataSource.checkSubscriptionStatus();
      return Right(result);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on TokenExpiredException catch (e) {
      return Left(TokenExpiredFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  Future<Either<Failure, SubscriptionEntity>> getMySubscription() async {
    try {
      final result = await remoteDataSource.getMySubscription();
      return Right(result);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on TokenExpiredException catch (e) {
      return Left(TokenExpiredFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }
}
