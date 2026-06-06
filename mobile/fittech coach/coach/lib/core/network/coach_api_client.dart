import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/session_store.dart';
import 'api_paths.dart';

class CoachApiClient {
  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    return _send('GET', endpoint, requiresAuth: requiresAuth);
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    return _send('POST', endpoint, body: body, requiresAuth: requiresAuth);
  }

  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    return _send('PATCH', endpoint, body: body, requiresAuth: requiresAuth);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
    bool retrying = false,
  }) async {
    final uri = Uri.parse('${ApiPaths.baseUrl}$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth) {
      final token = await SessionStore.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    late http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers);
        break;
      case 'PATCH':
        response = await _client.patch(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        );
        break;
      default:
        response = await _client.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        );
    }

    if (response.statusCode == 401 && requiresAuth && !retrying) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        return _send(
          method,
          endpoint,
          body: body,
          requiresAuth: requiresAuth,
          retrying: true,
        );
      }
    }

    final dynamic decoded = response.body.isEmpty
        ? {}
        : jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }

    throw Exception(_extractMessage(payload));
  }

  Future<bool> _refreshToken() async {
    final refresh = await SessionStore.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    final uri = Uri.parse('${ApiPaths.baseUrl}${ApiPaths.refreshToken}');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'refresh': refresh}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final access = payload['access']?.toString();
      if (access != null && access.isNotEmpty) {
        await SessionStore.saveTokens(access: access, refresh: refresh);
        return true;
      }
    }
    await SessionStore.clear();
    return false;
  }

  String _extractMessage(Map<String, dynamic> payload) {
    final detail = payload['detail']?.toString();
    if (detail != null && detail.isNotEmpty) return detail;
    final error = payload['error']?.toString();
    if (error != null && error.isNotEmpty) return error;
    final message = payload['message']?.toString();
    if (message != null && message.isNotEmpty) return message;
    for (final entry in payload.entries) {
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        return '${entry.key}: ${value.first}';
      }
      if (value is String && value.isNotEmpty) {
        return '${entry.key}: $value';
      }
    }
    return 'Request failed.';
  }
}
