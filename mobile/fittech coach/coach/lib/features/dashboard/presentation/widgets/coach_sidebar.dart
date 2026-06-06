import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/models/coach_profile.dart';
import '../screens/dashboard_screen.dart' show CoachTab;

class CoachSidebar extends StatelessWidget {
  const CoachSidebar({
    required this.profile,
    required this.currentTab,
    required this.expanded,
    required this.onSelectTab,
    required this.onOpenProfile,
    required this.onOpenCourses,
    required this.onLogout,
  });

  final CoachProfile profile;
  final CoachTab currentTab;
  final bool expanded;
  final ValueChanged<CoachTab> onSelectTab;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenCourses;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final width = expanded ? 240.0 : 92.0;
    return Container(
      width: width,
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.fromLTRB(
        expanded ? 18 : 10,
        18,
        expanded ? 18 : 10,
        18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2437),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: expanded
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          BrandLogo(compact: !expanded),
          const SizedBox(height: 24),
          SidebarNavItem(
            expanded: expanded,
            icon: Icons.calendar_today_outlined,
            label: 'Today\'s Classes',
            selected: currentTab == CoachTab.schedule,
            onTap: () => onSelectTab(CoachTab.schedule),
          ),
          const SizedBox(height: 10),
          SidebarNavItem(
            expanded: expanded,
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messaging',
            selected: currentTab == CoachTab.messaging,
            onTap: () => onSelectTab(CoachTab.messaging),
          ),
          const SizedBox(height: 10),
          SidebarNavItem(
            expanded: expanded,
            icon: Icons.school_outlined,
            label: 'My Courses',
            selected: false,
            onTap: onOpenCourses,
          ),
          const SizedBox(height: 10),
          SidebarNavItem(
            expanded: expanded,
            icon: Icons.person_outline_rounded,
            label: 'Coach Profile',
            selected: currentTab == CoachTab.profile,
            onTap: () => onSelectTab(CoachTab.profile),
          ),
          const Spacer(),
          InkWell(
            onTap: onOpenProfile,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(18),
              ),
              child: expanded
                  ? Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.green.withValues(
                            alpha: 0.18,
                          ),
                          child: Text(
                            profile.initials,
                            style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile.specialityLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onLogout,
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.green.withValues(
                            alpha: 0.18,
                          ),
                          child: Text(
                            profile.initials,
                            style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        IconButton(
                          onPressed: onLogout,
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class SidebarNavItem extends StatelessWidget {
  const SidebarNavItem({
    required this.expanded,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final bool expanded;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 12 : 10,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.green.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.green.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: expanded
            ? Row(
                children: [
                  Icon(
                    icon,
                    color: selected ? AppColors.green : AppColors.muted,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              )
            : Icon(
                icon,
                color: selected ? AppColors.green : AppColors.muted,
                size: 20,
              ),
      ),
    );
  }
}
