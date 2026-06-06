import 'package:equatable/equatable.dart';

class SubscriptionPlanEntity extends Equatable {
  final int id;
  final String name;
  final String planType;
  final double price;
  final int timesPerWeek;
  final int? durationDays;
  final int? sessionCount;
  final bool isActive;
  final bool isFeatured;
  final String? description;

  const SubscriptionPlanEntity({
    required this.id,
    required this.name,
    required this.planType,
    required this.price,
    required this.timesPerWeek,
    this.durationDays,
    this.sessionCount,
    this.isActive = true,
    this.isFeatured = false,
    this.description,
  });

  factory SubscriptionPlanEntity.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanEntity(
      id: json['id'] as int,
      name: json['name'] as String,
      planType: json['plan_type'] as String,
      price: json['price'] != null ? double.parse(json['price'].toString()) : 0.0,
      timesPerWeek: json['times_per_week'] as int? ?? 7,
      durationDays: json['duration_days'] as int?,
      sessionCount: json['session_count'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        planType,
        price,
        timesPerWeek,
        durationDays,
        sessionCount,
        isActive,
        isFeatured,
        description,
      ];
}

class SubscriptionEntity extends Equatable {
  final int id;
  final SubscriptionPlanEntity plan;
  final String status;
  final String startDate;
  final String? endDate;
  final int? sessionsRemaining;

  const SubscriptionEntity({
    required this.id,
    required this.plan,
    required this.status,
    required this.startDate,
    this.endDate,
    this.sessionsRemaining,
  });

  bool get isActive => status == 'active';

  factory SubscriptionEntity.fromJson(Map<String, dynamic> json) {
    return SubscriptionEntity(
      id: json['id'] as int,
      plan:
          SubscriptionPlanEntity.fromJson(json['plan'] as Map<String, dynamic>),
      status: json['status'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String?,
      sessionsRemaining: json['sessions_remaining'] as int?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        plan,
        status,
        startDate,
        endDate,
        sessionsRemaining,
      ];
}

class PaymentInitiationEntity extends Equatable {
  final String checkoutUrl;
  final String transactionId;
  final int paymentId;
  final int subscriptionId;

  const PaymentInitiationEntity({
    required this.checkoutUrl,
    required this.transactionId,
    required this.paymentId,
    required this.subscriptionId,
  });

  factory PaymentInitiationEntity.fromJson(Map<String, dynamic> json) {
    return PaymentInitiationEntity(
      checkoutUrl: json['checkout_url'] as String,
      transactionId: json['transaction_id'] as String,
      paymentId: json['payment_id'] as int,
      subscriptionId: json['subscription_id'] as int,
    );
  }

  @override
  List<Object?> get props => [
        checkoutUrl,
        transactionId,
        paymentId,
        subscriptionId,
      ];
}

class SubscriptionStatusEntity extends Equatable {
  final bool hasActiveSubscription;
  final SubscriptionEntity? subscription;

  const SubscriptionStatusEntity({
    required this.hasActiveSubscription,
    this.subscription,
  });

  factory SubscriptionStatusEntity.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatusEntity(
      hasActiveSubscription: json['has_active_subscription'] as bool? ?? false,
      subscription: json['subscription'] != null
          ? SubscriptionEntity.fromJson(
              json['subscription'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [hasActiveSubscription, subscription];
}
