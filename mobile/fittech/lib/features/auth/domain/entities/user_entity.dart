import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;
  final bool isEmailVerified;
  final String? photo;
  final String? fitnessGoal;
  final bool hasActiveSubscription;

  const UserEntity({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
    required this.isEmailVerified,
    this.photo,
    this.fitnessGoal,
    this.hasActiveSubscription = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'].toString(),
      email: (json['email'] ?? '') as String,
      firstName: (json['first_name'] ?? json['firstName'] ?? '') as String,
      lastName: (json['last_name'] ?? json['lastName'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      role: (json['role'] ?? 'member') as String,
      isEmailVerified:
          (json['email_verified'] ?? json['isEmailVerified'] ?? false) as bool,
      photo: json['photo']?.toString(),
      fitnessGoal: json['fitness_goal']?.toString(),
      hasActiveSubscription: (json['has_active_subscription'] ??
          json['hasActiveSubscription'] ??
          false) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'role': role,
      'email_verified': isEmailVerified,
      'photo': photo,
      'fitness_goal': fitnessGoal,
      'has_active_subscription': hasActiveSubscription,
    };
  }

  @override
  List<Object?> get props => [
        id,
        email,
        firstName,
        lastName,
        phone,
        role,
        isEmailVerified,
        photo,
        fitnessGoal,
        hasActiveSubscription,
      ];
}
