import 'package:equatable/equatable.dart';

class AccessLogEntity extends Equatable {
  final int id;
  final bool allowed;
  final String reason;
  final DateTime timestamp;
  final String? deviceUid;
  final String? deviceType;

  const AccessLogEntity({
    required this.id,
    required this.allowed,
    required this.reason,
    required this.timestamp,
    required this.deviceUid,
    required this.deviceType,
  });

  @override
  List<Object?> get props =>
      [id, allowed, reason, timestamp, deviceUid, deviceType];
}

class ScanResultEntity extends Equatable {
  final bool allowed;
  final String reason;

  const ScanResultEntity({required this.allowed, required this.reason});

  @override
  List<Object?> get props => [allowed, reason];
}
