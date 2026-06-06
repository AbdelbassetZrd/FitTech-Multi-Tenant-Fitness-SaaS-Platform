import '../../domain/entities/auth_tokens_entity.dart';
import '../../domain/entities/user_entity.dart';

class AuthResponseModel {
  final String accessToken;
  final String refreshToken;
  final UserEntity? user;

  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    // Support both snake_case and camelCase token key names
    final access =
        (json['access'] as String?) ?? (json['access_token'] as String?) ?? '';
    final refresh = (json['refresh'] as String?) ??
        (json['refresh_token'] as String?) ??
        '';

    UserEntity? user;
    final userJson = json['user'] ?? json['member'] ?? json['coach'];
    if (userJson is Map<String, dynamic>) {
      user = UserEntity.fromJson(userJson);
    }

    return AuthResponseModel(
      accessToken: access,
      refreshToken: refresh,
      user: user,
    );
  }

  AuthTokensEntity toEntity() => AuthTokensEntity(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
}
