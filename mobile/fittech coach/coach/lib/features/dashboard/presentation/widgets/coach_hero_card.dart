import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/coach_profile.dart';
import '../../../../core/network/api_paths.dart';

class CoachHeroCard extends StatelessWidget {
  const CoachHeroCard({required this.profile, required this.onProfileTap});

  final CoachProfile profile;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111B2F), Color(0xFF16243C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.green.withValues(alpha: 0.15),
            backgroundImage: profile.photoUrl != null
                ? NetworkImage(ApiPaths.resolveMedia(profile.photoUrl!))
                : null,
            child: profile.photoUrl == null
                ? Text(
                    profile.initials,
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.specialityLabel,
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile.yearsOfExperience} years experience • ${profile.isAvailable ? 'Available' : 'Unavailable'}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onProfileTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green.withValues(alpha: 0.18),
              foregroundColor: AppColors.green,
            ),
            child: const Text('Profile'),
          ),
        ],
      ),
    );
  }
}
