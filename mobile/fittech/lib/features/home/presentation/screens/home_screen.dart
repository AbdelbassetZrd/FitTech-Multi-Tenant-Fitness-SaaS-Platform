import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/fittech_theme.dart';
import '../../../../core/widgets/fit_bottom_nav_bar.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../subscription/presentation/widgets/subscription_lock_overlay.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<UserEntity?> _loadUser(BuildContext context) async {
    final repository = sl<AuthRepository>();
    final profileResult = await repository.getProfile();
    if (profileResult.isRight()) {
      return profileResult.getOrElse(
        () => throw StateError('Profile should be available.'),
      );
    }

    // If the profile fetch failed with an auth error, the stored token is
    // for a deleted/non-existent user — log out immediately.
    final failure = profileResult.fold((f) => f, (_) => null);
    if (failure is UnauthorizedFailure || failure is TokenExpiredFailure) {
      if (context.mounted) {
        context.read<AuthBloc>().add(const AuthLoggedOut());
      }
      return null;
    }

    final cachedResult = await repository.getCachedUser();
    return cachedResult.fold((_) => null, (user) => user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const FitBottomNavBar(currentIndex: 0),
      body: FitBackground(
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthUnauthenticated) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
          child: FutureBuilder<UserEntity?>(
            future: _loadUser(context),
            builder: (context, snapshot) {
              final user = snapshot.data;
              final hasSubscription = user?.hasActiveSubscription ?? false;

              return SafeArea(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HomeHeader(user: user),
                          const SizedBox(height: 16),
                          const _StatsRow(),
                          const SizedBox(height: 14),
                          _StartWorkoutButton(
                            onTap: () {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Workout flow coming soon.'),
                                  ),
                                );
                            },
                          ),
                          const SizedBox(height: 22),
                          const _SectionHeader(
                            title: 'Daily Goals',
                            trailing: _EditBadge(),
                          ),
                          const SizedBox(height: 12),
                          const _GoalCard(
                            label: 'ACTIVE GOAL',
                            title: 'Weight Loss',
                            trailing: '75%',
                            progress: 0.75,
                          ),
                          const SizedBox(height: 10),
                          const _GoalCard(
                            label: 'ACTIVE GOAL',
                            title: 'Strength Training',
                            trailing: '3/4 DAYS',
                            progress: 0.78,
                          ),
                          const SizedBox(height: 22),
                          _SectionHeader(
                            title: 'Upcoming Classes',
                            trailing: GestureDetector(
                              onTap: () => Navigator.pushReplacementNamed(
                                context,
                                '/schedule',
                              ),
                              child: const Text(
                                'SEE ALL',
                                style: TextStyle(
                                  color: FitColors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 248,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: const [
                                _ClassCard(
                                  badge: 'LIVE',
                                  title: 'HIIT INTENSITY',
                                  time: '5:30 PM',
                                  duration: '45 MIN',
                                  coach: 'COACH SARAH',
                                  imageUrl:
                                      'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=900&q=80',
                                ),
                                SizedBox(width: 12),
                                _ClassCard(
                                  badge: 'IN GYM',
                                  badgeColor: Color(0xFFFF5A5F),
                                  title: 'POWER CORE',
                                  time: '7:00 PM',
                                  duration: '60 MIN',
                                  coach: 'COACH OMAR',
                                  imageUrl:
                                      'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&w=900&q=80',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Center(
                            child: Text(
                              '"The only bad workout is the one that\n didn\'t happen."',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: FitColors.muted,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                    // Show lock overlay if no subscription
                    if (!hasSubscription)
                      SubscriptionLockOverlay(
                        onSubscribePressed: () {
                          Navigator.pushNamed(context, '/subscription');
                        },
                        title: 'Home Page Locked',
                        message:
                            'Subscribe to access workout recommendations and daily goals',
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final UserEntity? user;

  const _HomeHeader({this.user});

  @override
  Widget build(BuildContext context) {
    final imageProvider = _profileImage(user);

    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: FitColors.green.withValues(alpha: 0.45),
              width: 2,
            ),
            image: imageProvider != null
                ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                : null,
          ),
          child: imageProvider == null
              ? const Icon(Icons.person, color: Colors.white, size: 24)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GOOD MORNING,',
                style: TextStyle(
                  color: FitColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.fullName.isNotEmpty == true
                    ? user!.fullName
                    : 'FitTech Member',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        _HeaderIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          onTap: () => Navigator.pushNamed(context, '/messaging'),
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          showDot: true,
          onTap: () => Navigator.pushReplacementNamed(context, '/profile'),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF202A42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            if (showDot)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: FitColors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.directions_walk_rounded,
            label: 'STEPS',
            value: '8,432',
            unit: 'Goal: 10k',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_outlined,
            label: 'KCAL',
            value: '450',
            unit: 'Burned',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.access_time_rounded,
            label: 'TIME',
            value: '45',
            unit: 'Mins',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF222D46),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FitColors.green, size: 18),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: FitColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unit,
            style: const TextStyle(
              color: FitColors.muted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

ImageProvider<Object>? _profileImage(UserEntity? user) {
  final photo = user?.photo;
  if (photo == null || photo.isEmpty) return null;

  final resolved = photo.startsWith('http')
      ? photo
      : '${AppConstants.baseUrl}${photo.startsWith('/') ? '' : '/'}$photo';
  return NetworkImage(resolved);
}

class _StartWorkoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StartWorkoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, size: 16, color: FitColors.green),
        ),
        label: const Text(
          'START WORKOUT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2ED06E),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget trailing;

  const _SectionHeader({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        trailing,
      ],
    );
  }
}

class _EditBadge extends StatelessWidget {
  const _EditBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF22324B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'EDIT',
        style: TextStyle(
          color: FitColors.green,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String label;
  final String title;
  final String trailing;
  final double progress;

  const _GoalCard({
    required this.label,
    required this.title,
    required this.trailing,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202A42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: FitColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(
                  color: FitColors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF2B3751),
              valueColor: const AlwaysStoppedAnimation(FitColors.green),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final String badge;
  final Color badgeColor;
  final String title;
  final String time;
  final String duration;
  final String coach;
  final String imageUrl;

  const _ClassCard({
    required this.badge,
    this.badgeColor = FitColors.green,
    required this.title,
    required this.time,
    required this.duration,
    required this.coach,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 214,
      decoration: BoxDecoration(
        color: const Color(0xFF202A42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 126,
                    width: double.infinity,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFF26334E),
                          child: const Center(
                            child: Icon(
                              Icons.fitness_center_rounded,
                              color: Colors.white70,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.14),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _Pill(text: badge, color: badgeColor),
                ),
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.whatshot_rounded,
                    color: Color(0xFFFFC542),
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    color: FitColors.green, size: 14),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: const TextStyle(
                    color: FitColors.label,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.timelapse_rounded,
                    color: FitColors.green, size: 14),
                const SizedBox(width: 6),
                Text(
                  duration,
                  style: const TextStyle(
                    color: FitColors.label,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF31405F),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFFFFC27A),
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  coach,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}
