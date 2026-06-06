import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';
import '../errors/exceptions.dart';

class TokenStorage {
  Box? _box;

  Future<void> init() async {
    _box = await Hive.openBox(AppConstants.tokenBoxName);
  }

  Box get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw const CacheException('TokenStorage not initialised.');
    }
    return _box!;
  }

  // ── Tokens ─────────────────────────────────────────────────────────────────
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _safeBox.put(AppConstants.accessTokenKey, accessToken);
    await _safeBox.put(AppConstants.refreshTokenKey, refreshToken);
  }

  Future<void> saveAccessToken(String token) async =>
      _safeBox.put(AppConstants.accessTokenKey, token);

  Future<String?> getAccessToken() async =>
      _safeBox.get(AppConstants.accessTokenKey) as String?;

  Future<String?> getRefreshToken() async =>
      _safeBox.get(AppConstants.refreshTokenKey) as String?;

  // ── User ───────────────────────────────────────────────────────────────────
  Future<void> saveUser(Map<String, dynamic> user) async =>
      _safeBox.put(AppConstants.userKey, user);

  Future<Map<String, dynamic>?> getUser() async {
    final raw = _safeBox.get(AppConstants.userKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }

  // ── Subscription ──────────────────────────────────────────────────────────
  Future<void> saveSubscription(Map<String, dynamic> subscription) async =>
      _safeBox.put(AppConstants.subscriptionKey, subscription);

  Future<Map<String, dynamic>?> getSubscription() async {
    final raw = _safeBox.get(AppConstants.subscriptionKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<void> clearSubscription() async =>
      _safeBox.delete(AppConstants.subscriptionKey);

  // ── Helpers ────────────────────────────────────────────────────────────────
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearAll() async => _safeBox.clear();
}
