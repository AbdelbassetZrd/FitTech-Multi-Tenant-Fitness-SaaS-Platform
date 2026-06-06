import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/access_log_entity.dart';
import '../models/access_log_model.dart';
import '../models/access_status_model.dart';

abstract class NfcRemoteDataSource {
  Future<AccessStatusModel> getStatus();
  Future<List<AccessLogModel>> getHistory({int limit = 20});
  Future<ScanResultEntity> simulateScan();
  Future<String> registerNfcCard(String uid, String deviceType);
}

class NfcRemoteDataSourceImpl implements NfcRemoteDataSource {
  final ApiClient apiClient;

  NfcRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<AccessStatusModel> getStatus() async {
    final response = await apiClient.authGet(AppConstants.accessMe);
    return AccessStatusModel.fromJson(response);
  }

  @override
  Future<List<AccessLogModel>> getHistory({int limit = 20}) async {
    final response = await apiClient.authGet(
      AppConstants.accessHistory,
      queryParams: {'limit': '$limit'},
    );
    final raw = response['results'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => AccessLogModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<ScanResultEntity> simulateScan() async {
    final response = await apiClient.authPost(AppConstants.accessMeScan);
    return ScanResultEntity(
      allowed: response['allowed'] == true,
      reason: response['reason']?.toString() ?? '',
    );
  }

  @override
  Future<String> registerNfcCard(String uid, String deviceType) async {
    final response = await apiClient.authPost(
      AppConstants.accessMeRegisterCard,
      body: {'uid': uid, 'device_type': deviceType},
    );
    return response['message']?.toString() ?? 'Card registered.';
  }
}
