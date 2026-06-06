import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/fittech_theme.dart';
import 'exercise_pose_monitor_mobile_screen.dart';

class ExercisePoseMonitorScreen extends StatelessWidget {
  final String exerciseName;
  final String bodyPart;
  final String target;

  const ExercisePoseMonitorScreen({
    super.key,
    required this.exerciseName,
    required this.bodyPart,
    required this.target,
  });

  bool get _isSupportedMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    if (_isSupportedMobilePlatform) {
      return ExercisePoseMonitorMobileScreen(
        exerciseName: exerciseName,
        bodyPart: bodyPart,
        target: target,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(exerciseName),
      ),
      body: const _PoseMonitorUnavailableView(),
    );
  }
}

class _PoseMonitorUnavailableView extends StatelessWidget {
  const _PoseMonitorUnavailableView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161E32),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded,
                  size: 36, color: FitColors.green),
              SizedBox(height: 14),
              Text(
                'Pose monitoring unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Live camera pose monitoring is available on Android and iPhone. Use a mobile device to access camera-based rep tracking.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FitColors.label,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
