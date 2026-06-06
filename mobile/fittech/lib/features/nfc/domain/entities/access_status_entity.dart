import 'package:equatable/equatable.dart';

class AccessStatusEntity extends Equatable {
  final String membershipId;
  final String fullName;
  final String roleLabel;
  final String? nfcUid;
  final String? deviceType;
  final bool isConnected;
  final bool subscriptionActive;
  final String planLabel;

  const AccessStatusEntity({
    required this.membershipId,
    required this.fullName,
    required this.roleLabel,
    required this.nfcUid,
    required this.deviceType,
    required this.isConnected,
    required this.subscriptionActive,
    required this.planLabel,
  });

  bool get hasDevice => nfcUid != null && nfcUid!.isNotEmpty;

  @override
  List<Object?> get props => [
        membershipId,
        fullName,
        roleLabel,
        nfcUid,
        deviceType,
        isConnected,
        subscriptionActive,
        planLabel,
      ];
}
