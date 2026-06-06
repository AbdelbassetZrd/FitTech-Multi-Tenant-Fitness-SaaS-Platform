import '../../../../core/network/api_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/subscription_entity.dart';

class SubscriptionRemoteDataSource {
  final ApiClient apiClient;

  SubscriptionRemoteDataSource({
    required this.apiClient,
  });

  Future<List<SubscriptionPlanEntity>> getSubscriptionPlans() async {
    try {
      final response = await apiClient.get('/api/subscriptions/plans/', requiresAuth: false);
      final List<dynamic> data = response is List ? response : response['data'] ?? response;
      return data
          .map((item) =>
              SubscriptionPlanEntity.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<PaymentInitiationEntity> initiateChargilyPayment(int planId) async {
    try {
      final response = await apiClient.authPost(
        '/api/subscriptions/chargily/initiate/',
        body: {'plan_id': planId},
      );
      return PaymentInitiationEntity.fromJson(response);
    } catch (e) {
      if (e is ServerException || e is UnauthorizedException || e is ValidationException || e is TokenExpiredException) {
        rethrow;
      }
      throw ServerException(e.toString());
    }
  }

  Future<SubscriptionStatusEntity> verifyChargilyPayment({
    required String transactionId,
    required int paymentId,
  }) async {
    try {
      final response = await apiClient.authPost(
        '/api/subscriptions/chargily/verify/',
        body: {
          'transaction_id': transactionId,
          'payment_id': paymentId,
        },
      );
      // Wait, verify might return status 200 or 202. ApiClient handles this.
      // But we need to return SubscriptionStatusEntity, so we can just call checkSubscriptionStatus
      return await checkSubscriptionStatus();
    } catch (e) {
      if (e is ServerException || e is UnauthorizedException || e is ValidationException || e is TokenExpiredException) {
        rethrow;
      }
      throw ServerException(e.toString());
    }
  }

  Future<SubscriptionStatusEntity> checkSubscriptionStatus() async {
    try {
      final response = await apiClient.authGet('/api/subscriptions/chargily/status/');
      return SubscriptionStatusEntity.fromJson(response);
    } catch (e) {
      if (e is ServerException || e is UnauthorizedException || e is ValidationException || e is TokenExpiredException) {
        rethrow;
      }
      throw ServerException(e.toString());
    }
  }

  Future<SubscriptionEntity> getMySubscription() async {
    try {
      final response = await apiClient.authGet('/api/subscriptions/my/');
      return SubscriptionEntity.fromJson(response);
    } catch (e) {
      if (e is ServerException || e is UnauthorizedException || e is ValidationException || e is TokenExpiredException) {
        rethrow;
      }
      throw ServerException(e.toString());
    }
  }
}
