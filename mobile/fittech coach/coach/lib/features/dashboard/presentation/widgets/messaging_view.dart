import 'package:flutter/material.dart';
import '../../../../core/models/coach_profile.dart';
import '../../../messaging/presentation/screens/messaging_screen.dart';

class MessagingViewWidget extends StatelessWidget {
  const MessagingViewWidget({required this.profile, required this.wide});

  final CoachProfile profile;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return MessagingScreen(profile: profile, wide: wide);
  }
}
