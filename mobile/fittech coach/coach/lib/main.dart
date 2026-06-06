import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/launch_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/courses/presentation/screens/courses_list_screen.dart';
import 'features/courses/presentation/screens/course_detail_screen.dart';
import 'features/dashboard/presentation/screens/attendance_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const CoachApp());
}

class CoachApp extends StatelessWidget {
  const CoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FitTech Coach',
      theme: AppTheme.darkTheme,
      home: const LaunchScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/courses': (context) => const CoursesListScreen(),
        '/courses/detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          final courseId = args is int
              ? args
              : int.tryParse(args?.toString() ?? '0') ?? 0;
          return CourseDetailScreen(courseId: courseId);
        },
        '/sessions/attendance': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
          final sessionId = args?['sessionId'] as int? ?? 0;
          final bookings = args?['bookings'] as List<dynamic>? ?? [];
          return AttendanceScreen(sessionId: sessionId, bookings: bookings);
        },
      },
    );
  }
}
