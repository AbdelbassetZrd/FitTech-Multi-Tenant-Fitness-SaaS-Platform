import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/user_entity.dart';
import '../models/auth_response_model.dart';

// ─── Abstract ─────────────────────────────────────────────────────────────────
abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  });

  Future<AuthResponseModel> register({
    required String email,
    required String password,
    required String password2,
    required String firstName,
    required String lastName,
    required String phone,
    required String role,
  });

  Future<void> logout();

  Future<AuthResponseModel> verifyEmail({
    required String email,
    required String code,
  });

  Future<void> resendVerification({required String email});

  Future<UserEntity> getProfile();

  // POST /api/auth/token/refresh/ → returns new access token string
  Future<String> refreshToken({required String refresh});
}

// ─── Implementation ───────────────────────────────────────────────────────────
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  const AuthRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final json = await _apiClient.post(
      AppConstants.login,
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );
    return AuthResponseModel.fromJson(json);
  }

  @override
  Future<AuthResponseModel> register({
    required String email,
    required String password,
    required String password2,
    required String firstName,
    required String lastName,
    required String phone,
    required String role,
  }) async {
    final json = await _apiClient.post(
      AppConstants.register,
      body: {
        'email': email,
        'password': password,
        'confirm_password': password2,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      },
      requiresAuth: false,
    );
    return AuthResponseModel.fromJson(json);
  }

  @override
  Future<void> logout() async {
    await _apiClient.post(AppConstants.logout, requiresAuth: true);
  }

  @override
  Future<AuthResponseModel> verifyEmail({
    required String email,
    required String code,
  }) async {
    final json = await _apiClient.post(
      AppConstants.verifyEmail,
      body: {'email': email, 'otp_code': code},
      requiresAuth: false,
    );
    return AuthResponseModel.fromJson(json);
  }

  @override
  Future<void> resendVerification({required String email}) async {
    await _apiClient.post(
      AppConstants.resendVerification,
      body: {'email': email},
      requiresAuth: false,
    );
  }

  @override
  Future<UserEntity> getProfile() async {
    final json = await _apiClient.authGet(AppConstants.profile);
    return UserEntity.fromJson(json);
  }

  @override
  Future<String> refreshToken({required String refresh}) async {
    final json = await _apiClient.post(
      AppConstants.refreshToken,
      body: {'refresh': refresh},
      requiresAuth: false,
    );
    return (json['access'] as String?) ?? '';
  }
}
