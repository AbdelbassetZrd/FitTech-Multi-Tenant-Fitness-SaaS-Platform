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

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<UserEntity?> _loadUser(BuildContext context) async {
    final repository = sl<AuthRepository>();
    final profileResult = await repository.getProfile();
    if (profileResult.isRight()) {
      return profileResult.getOrElse(
        () => throw StateError('Profile should be available.'),
      );
    }

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
      bottomNavigationBar: const FitBottomNavBar(currentIndex: 4),
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
              final photo = _profileImage(user);

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const FitBackButton(),
                          const Spacer(),
                          _NfcIconButton(
                            onTap: () => Navigator.pushNamed(context, '/nfc'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: FitColors.surface,
                                border: Border.all(
                                  color:
                                      FitColors.green.withValues(alpha: 0.35),
                                  width: 2,
                                ),
                                image: photo != null
                                    ? DecorationImage(
                                        image: photo,
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: photo == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 44,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              user?.fullName.isNotEmpty == true
                                  ? user!.fullName
                                  : 'FitTech Member',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_capitalize(user?.role ?? 'member')} • ${user?.isEmailVerified == true ? 'Verified' : 'Pending verification'}',
                              style: const TextStyle(
                                color: FitColors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _ProfileSection(
                        title: 'ACCOUNT',
                        children: [
                          _ProfileRow(
                              label: 'Email', value: user?.email ?? '—'),
                          _ProfileRow(
                              label: 'Phone',
                              value: user?.phone.isNotEmpty == true
                                  ? user!.phone
                                  : 'Not set'),
                          _ProfileRow(
                              label: 'Role',
                              value: _capitalize(user?.role ?? 'member')),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _ProfileSection(
                        title: 'FITNESS',
                        children: [
                          _ProfileRow(
                              label: 'Goal',
                              value: _fitnessGoalLabel(user?.fitnessGoal)),
                          const _ProfileRow(
                              label: 'Level', value: 'Intermediate'),
                          const _ProfileRow(
                              label: 'Weekly Target', value: '4 sessions'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _MenuTile(
                        icon: Icons.home_outlined,
                        title: 'Go to Home',
                        subtitle: 'Open your training dashboard.',
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/home'),
                      ),
                      const SizedBox(height: 12),
                      _MenuTile(
                        icon: Icons.workspace_premium_outlined,
                        title: 'Subscription Dashboard',
                        subtitle:
                            'See your active plan, renewal date and time left.',
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/subscription-dashboard',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _MenuTile(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Manage Subscription',
                        subtitle: 'Browse plans and change your package.',
                        onTap: () =>
                            Navigator.pushNamed(context, '/subscription'),
                      ),
                      const SizedBox(height: 12),
                      _MenuTile(
                        icon: Icons.logout,
                        title: 'Logout',
                        subtitle: 'Sign out and clear your session.',
                        onTap: () {
                          context.read<AuthBloc>().add(const AuthLoggedOut());
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
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

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _fitnessGoalLabel(String? goal) {
  if (goal == null || goal.isEmpty) return 'Not set';
  return goal.split('_').map(_capitalize).join(' ');
}

class _NfcIconButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NfcIconButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: FitColors.green.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: FitColors.green.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.contactless_rounded,
          color: FitColors.green,
          size: 22,
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FitColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: FitColors.label,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: FitColors.muted,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: FitColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: FitColors.green.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: FitColors.green),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: FitColors.label,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: FitColors.hint),
          ],
        ),
      ),
    );
  }
}
