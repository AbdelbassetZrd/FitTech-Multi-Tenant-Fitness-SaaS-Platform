import '../../domain/entities/access_status_entity.dart';

class AccessStatusModel extends AccessStatusEntity {
  const AccessStatusModel({
    required super.membershipId,
    required super.fullName,
    required super.roleLabel,
    required super.nfcUid,
    required super.deviceType,
    required super.isConnected,
    required super.subscriptionActive,
    required super.planLabel,
  });

  factory AccessStatusModel.fromJson(Map<String, dynamic> json) {
    return AccessStatusModel(
      membershipId: json['membership_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      roleLabel: json['role']?.toString() ?? 'MEMBER',
      nfcUid: json['nfc_uid']?.toString(),
      deviceType: json['device_type']?.toString(),
      isConnected: json['is_connected'] == true,
      subscriptionActive: json['subscription_active'] == true,
      planLabel: json['plan_label']?.toString() ?? '',
    );
  }
}
