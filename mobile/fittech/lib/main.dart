import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'core/fittech_theme.dart';
import 'injection_container.dart' as di;
import 'injection_container.dart';

import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/login_bloc.dart';
import 'features/auth/presentation/bloc/register_bloc.dart';
import 'features/auth/presentation/bloc/verify_email_bloc.dart';

import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/forgot_password_screen.dart';
import 'features/auth/presentation/screens/confirm_email_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/courses/presentation/screens/course_booking_screen.dart';
import 'features/subscription/presentation/screens/subscription_management_screen.dart';
import 'features/subscription/presentation/screens/subscription_dashboard_screen.dart';
import 'features/subscription/presentation/screens/checkout_screen.dart';
import 'features/workout/presentation/screens/progress_screen.dart';
import 'features/workout/presentation/screens/workout_screen.dart';
import 'features/messaging/presentation/screens/messaging_screen.dart';
import 'features/nfc/presentation/screens/nfc_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialise Hive
  await Hive.initFlutter();

  // 2. Wire all dependencies (also opens the Hive box inside TokenStorage)
  await di.initDependencies();

  // 2a. Ensure WebView platform is registered before any widget uses it.
  //     The auto-registrant should handle this, but we set it explicitly
  //     as a safety measure against stale build caches.
  if (WebViewPlatform.instance == null) {
    if (Platform.isAndroid) {
      WebViewPlatform.instance = AndroidWebViewPlatform();
    } else if (Platform.isIOS) {
      WebViewPlatform.instance = WebKitWebViewPlatform();
    }
  }

  // 3. Lock orientation + transparent status bar
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const FitTechApp());
}

class FitTechApp extends StatelessWidget {
  const FitTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // AuthBloc lives for the full app lifetime — singleton in GetIt
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>(),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: 'FitTech Premium',
        debugShowCheckedModeBanner: false,

        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          colorScheme: const ColorScheme.dark(
            primary: FitColors.green,
            secondary: FitColors.green,
            surface: FitColors.surface,
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: _FadeSlideTransition(),
              TargetPlatform.iOS: _FadeSlideTransition(),
            },
          ),
        ),

        initialRoute: '/splash',

        // ─────────────────────────────────────────────────────────────────────
        // Route table
        //
        //  /splash           → SplashScreen       reads AuthBloc → /login | /subscription
        //  /login            → LoginScreen         LoginBloc
        //  /register         → RegisterScreen      RegisterBloc
        //  /forgot-password  → ForgotPasswordScreen VerifyEmailBloc (resend)
        //  /confirm-email    → ConfirmEmailScreen  VerifyEmailBloc (verify + countdown)
        //                      expects arguments: Map {'email': String}
        //  /home             → HomeScreen
        //  /workouts         → WorkoutScreen
        //  /progress         → ProgressScreen
        //  /schedule         → CourseBookingScreen
        //  /profile          → ProfileScreen
        //  /subscription     → SubscriptionScreen
        //  /subscription-dashboard → SubscriptionDashboardScreen
        //  /checkout         → CheckoutScreen
        //                      expects arguments: Map {'planName','price','currency'}
        // ─────────────────────────────────────────────────────────────────────
        routes: {
          '/splash': (_) => const SplashScreen(),
          '/login': (_) => BlocProvider<LoginBloc>(
                create: (_) => sl<LoginBloc>(),
                child: const LoginScreen(),
              ),
          '/register': (_) => BlocProvider<RegisterBloc>(
                create: (_) => sl<RegisterBloc>(),
                child: const RegisterScreen(),
              ),
          '/forgot-password': (_) => BlocProvider<VerifyEmailBloc>(
                create: (_) => sl<VerifyEmailBloc>(),
                child: const ForgotPasswordScreen(),
              ),
          '/confirm-email': (_) => BlocProvider<VerifyEmailBloc>(
                create: (_) => sl<VerifyEmailBloc>(),
                child: const ConfirmEmailScreen(),
              ),
          '/home': (_) => const HomeScreen(),
          '/workouts': (_) => const WorkoutScreen(),
          '/progress': (_) => const ProgressScreen(),
          '/schedule': (_) => const CourseBookingScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/subscription': (_) => const SubscriptionManagementScreen(),
          '/subscription-dashboard': (_) => const SubscriptionDashboardScreen(),
          '/checkout': (_) => const CheckoutScreen(),
          '/messaging': (_) => const MessagingScreen(),
          '/nfc': (_) => const NfcScreen(),
        },

        onUnknownRoute: (settings) => MaterialPageRoute<void>(
          builder: (_) => BlocProvider<LoginBloc>(
            create: (_) => sl<LoginBloc>(),
            child: const LoginScreen(),
          ),
        ),
      ),
    );
  }
}

// ─── Fade + subtle slide page transition ─────────────────────────────────────
class _FadeSlideTransition extends PageTransitionsBuilder {
  const _FadeSlideTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(0.05, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );

    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.75, curve: Curves.easeIn),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
