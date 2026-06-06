import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';
import '../errors/exceptions.dart';
import '../storage/token_storage.dart';

class ApiClient {
  final http.Client _client;
  final TokenStorage _tokenStorage;
  final Logger _log = Logger();

  ApiClient({required http.Client client, required TokenStorage tokenStorage})
      : _client = client,
        _tokenStorage = tokenStorage;

  // ── Headers ────────────────────────────────────────────────────────────────
  Future<Map<String, String>> _headers({bool requiresAuth = true}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (requiresAuth) {
      final token = await _tokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        h['Authorization'] = 'Bearer $token';
      }
    }
    return h;
  }

  // ── GET ────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool requiresAuth = true,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint')
        .replace(queryParameters: queryParams);
    _log.i('GET $uri');
    try {
      final res = await _client
          .get(uri, headers: await _headers(requiresAuth: requiresAuth))
          .timeout(AppConstants.connectTimeout);
      return _handle(res);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('Request timed out.');
    }
  }

  // ── POST ───────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    _log.i('POST $uri  body=$body');
    try {
      final res = await _client
          .post(
            uri,
            headers: await _headers(requiresAuth: requiresAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConstants.connectTimeout);
      return _handle(res);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('Request timed out.');
    }
  }

  // ── Authenticated POST with auto-refresh ───────────────────────────────────
  Future<Map<String, dynamic>> authPost(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      return await post(endpoint, body: body, requiresAuth: true);
    } on UnauthorizedException {
      if (await _silentRefresh()) {
        return await post(endpoint, body: body, requiresAuth: true);
      }
      rethrow;
    } on TokenExpiredException {
      if (await _silentRefresh()) {
        return await post(endpoint, body: body, requiresAuth: true);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> authGet(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      return await get(
        endpoint,
        requiresAuth: true,
        queryParams: queryParams,
      );
    } on UnauthorizedException {
      if (await _silentRefresh()) {
        return await get(
          endpoint,
          requiresAuth: true,
          queryParams: queryParams,
        );
      }
      rethrow;
    } on TokenExpiredException {
      if (await _silentRefresh()) {
        return await get(
          endpoint,
          requiresAuth: true,
          queryParams: queryParams,
        );
      }
      rethrow;
    }
  }

  // ── Silent token refresh ───────────────────────────────────────────────────
  Future<bool> _silentRefresh() async {
    try {
      final refresh = await _tokenStorage.getRefreshToken();
      if (refresh == null) return false;
      final resp = await post(
        AppConstants.refreshToken,
        body: {'refresh': refresh},
        requiresAuth: false,
      );
      final newAccess = resp['access'] as String?;
      if (newAccess != null) {
        await _tokenStorage.saveAccessToken(newAccess);
        _log.i('Token silently refreshed.');
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Response handler ───────────────────────────────────────────────────────
  Map<String, dynamic> _handle(http.Response res) {
    _log.d('Response [${res.statusCode}]: ${res.body}');

    if (res.statusCode == 204) return {};

    late Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } catch (_) {
      body = <String, dynamic>{'detail': res.body};
    }

    switch (res.statusCode) {
      case 200:
      case 201:
        return body;
      case 400:
        throw ValidationException(
          _extractMessage(body) ?? 'Validation error.',
          errors: body,
        );
      case 401:
        final msg = _extractMessage(body) ?? 'Unauthorized.';
        if (msg.toLowerCase().contains('token')) {
          throw TokenExpiredException(msg);
        }
        throw UnauthorizedException(msg);
      case 403:
        throw UnauthorizedException(_extractMessage(body) ?? 'Forbidden.');
      case 404:
        throw ServerException(_extractMessage(body) ?? 'Not found.',
            statusCode: 404);
      default:
        throw ServerException(
          _extractMessage(body) ?? 'Server error.',
          statusCode: res.statusCode,
        );
    }
  }

  String? _extractMessage(Map<String, dynamic> body) {
    if (body.containsKey('detail')) {
      return body['detail']?.toString();
    }
    if (body.containsKey('message')) {
      return body['message']?.toString();
    }
    if (body.containsKey('error')) {
      return body['error']?.toString();
    }
    final nonField = body['non_field_errors'];
    if (nonField is List && nonField.isNotEmpty) {
      return nonField.first.toString();
    }
    final msgs = <String>[];
    body.forEach((k, v) {
      if (v is List) {
        msgs.add('$k: ${v.join(', ')}');
      } else if (v is String) {
        msgs.add('$k: $v');
      }
    });
    return msgs.isNotEmpty ? msgs.join('\n') : null;
  }
}
