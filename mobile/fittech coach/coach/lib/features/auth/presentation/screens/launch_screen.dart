import 'package:flutter/material.dart';
import '../../../../core/network/coach_api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_logo.dart';
import 'login_screen.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen();

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  final _api = CoachApiClient();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hasToken = await SessionStore.hasAccessToken();
    if (!mounted) return;
    if (!hasToken) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    try {
      await _api.get(ApiPaths.profile, requiresAuth: true);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (_) {
      await SessionStore.clear();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF08101D), Color(0xFF111C31)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(),
              SizedBox(height: 20),
              CircularProgressIndicator(color: AppColors.green),
            ],
          ),
        ),
      ),
    );
  }
}
