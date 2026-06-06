import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  // ─── Base URL ──────────────────────────────────────────────────────────────
  /// Public ngrok tunnel — used by the NFC reader app and any external device.
  /// Update this whenever you restart ngrok with a new URL.
  static const String ngrokBaseUrl =
      'https://providing-april-manger.ngrok-free.dev';

  static String get baseUrl {
    const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envBaseUrl.isNotEmpty) return envBaseUrl;

    if (kIsWeb) return 'http://127.0.0.1:8000';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return ngrokBaseUrl;
      default:
        return 'http://127.0.0.1:8000';
    }
  }

  // ─── Auth Endpoints ────────────────────────────────────────────────────────
  static const String register = '/api/auth/members/register/';
  static const String login = '/api/auth/members/login/';
  static const String logout = '/api/auth/members/logout/';
  static const String verifyEmail = '/api/auth/members/verify-otp/';
  static const String resendVerification = '/api/auth/members/request-otp/';
  static const String refreshToken = '/api/auth/token/refresh/';
  static const String profile = '/api/auth/members/profile/';
  static const String profileUpdate = '/api/auth/members/profile/update/';

  // ─── Subscription Endpoints ───────────────────────────────────────────────
  static const String subscriptionPlans = '/api/subscriptions/plans/';

  // ─── Courses Endpoints ────────────────────────────────────────────────────
  static const String coursesList = '/api/courses/list/';
  static const String courseSessions = '/api/courses/sessions/';
  static const String myCourseBookings = '/api/courses/my-bookings/';
  static const String courseMemberDashboard = '/api/courses/member/dashboard/';
  static const String courseAbsenceWarnings = '/api/courses/absence-warnings/';

  static String bookCourse(int courseId) => '/api/courses/$courseId/book/';

  static String cancelCourse(int courseId) => '/api/courses/$courseId/cancel/';

  static String initiateCoursePayment(int courseId) =>
      '/api/courses/$courseId/initiate-payment/';

  static const String verifyCoursePayment =
      '/api/courses/verify-course-payment/';

  // ─── Messaging Endpoints ──────────────────────────────────────────────────
  static const String messagingContacts = '/api/messaging/contacts/';
  static const String messagingInbox = '/api/messaging/inbox/';
  static const String messagingSend = '/api/messaging/send/';
  static const String messagingBotChat = '/api/messaging/bot/';
  static const String messagingBotHistory = '/api/messaging/bot-history/';
  static const String botContactId = 'nutrition-bot';
  static String messagingMarkRead(int messageId) =>
      '/api/messaging/$messageId/read/';

  // ─── Access Control / NFC Endpoints ───────────────────────────────────────
  static const String accessMe = '/api/access/me/';
  static const String accessMeScan = '/api/access/me/scan/';
  static const String accessMeRegisterCard = '/api/access/me/register-card/';
  static const String accessHistory = '/api/access/history/';

  // ─── Workout Endpoints ────────────────────────────────────────────────────
  static const String workoutList = '/api/workouts/list/';
  static const String workoutLog = '/api/workouts/log/';
  static const String workoutProgression = '/api/workouts/progression/';

  // ─── ExerciseDB ───────────────────────────────────────────────────────────
  static const String exerciseDbBaseUrl = 'https://exercisedb.p.rapidapi.com';
  static const String exerciseDbHost = 'exercisedb.p.rapidapi.com';
  static const String exerciseDbKey = String.fromEnvironment(
    'RAPIDAPI_KEY',
    defaultValue: '7b3c054966mshaba182cb04d0e73p1b9b66jsn987da31c6f4b',
  );

  // ─── Hive Box / Keys ──────────────────────────────────────────────────────
  static const String tokenBoxName = 'token_box';
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String subscriptionKey = 'subscription_data';

  // ─── Timeouts ─────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 30);
}
