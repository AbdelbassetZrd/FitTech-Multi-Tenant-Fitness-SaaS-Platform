import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ApiPaths {
  static String get baseUrl {
    const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envBaseUrl.isNotEmpty) return envBaseUrl;
    if (kIsWeb) return 'http://127.0.0.1:8000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }

  static const login = '/api/auth/coaches/login/';
  static const profile = '/api/auth/coaches/profile/';
  static const profileUpdate = '/api/auth/coaches/profile/update/';
  static const passwordChange = '/api/auth/coaches/password/change/';
  static const resetPassword = '/api/auth/coaches/password/reset/';
  static const resetPasswordConfirm =
      '/api/auth/coaches/password/reset/confirm/';
  static const refreshToken = '/api/auth/token/refresh/';

  static const coachSessions = '/api/courses/coach/sessions/';
  static const coachStats = '/api/courses/coach/sessions/stats/';
  static const coachEarnings = '/api/courses/coach/earnings/';
  static const absenceWarnings = '/api/courses/absence-warnings/';
  static const coachCourses = '/api/courses/coach/courses/';
  static String coachCourseDetail(int id) => '/api/courses/coach/courses/$id/';

  static String attendance(int sessionId) =>
      '/api/courses/sessions/$sessionId/attendance/';

  // ── Messaging ─────────────────────────────────────────────────────────────
  static const messagingContacts = '/api/messaging/contacts/';
  static const messagingInbox = '/api/messaging/inbox/';
  static const messagingSend = '/api/messaging/send/';

  static String resolveMedia(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '$baseUrl$path';
    return '$baseUrl/$path';
  }
}
