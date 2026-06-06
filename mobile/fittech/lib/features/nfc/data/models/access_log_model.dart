import '../../domain/entities/access_log_entity.dart';

class AccessLogModel extends AccessLogEntity {
  const AccessLogModel({
    required super.id,
    required super.allowed,
    required super.reason,
    required super.timestamp,
    required super.deviceUid,
    required super.deviceType,
  });

  factory AccessLogModel.fromJson(Map<String, dynamic> json) {
    return AccessLogModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      allowed: json['allowed'] == true,
      reason: json['reason']?.toString() ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      deviceUid: json['device_uid']?.toString(),
      deviceType: json['device_type']?.toString(),
    );
  }
}
