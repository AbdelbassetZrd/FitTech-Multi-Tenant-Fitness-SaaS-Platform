import 'package:flutter/material.dart';

import '../fittech_theme.dart';

class FitBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const FitBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    const items = <_NavItem>[
      _NavItem(label: 'Home', icon: Icons.home_rounded, route: '/home'),
      _NavItem(
        label: 'Workouts',
        icon: Icons.fitness_center_rounded,
        route: '/workouts',
      ),
      _NavItem(
        label: 'Schedule',
        icon: Icons.calendar_month_rounded,
        route: '/schedule',
      ),
      _NavItem(
        label: 'Progress',
        icon: Icons.show_chart_rounded,
        route: '/progress',
      ),
      _NavItem(label: 'Profile', icon: Icons.person_rounded, route: '/profile'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151C2F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = currentIndex == index;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (item.route == null) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('This section is coming soon.'),
                      ),
                    );
                  return;
                }

                if (isSelected) return;
                Navigator.pushReplacementNamed(context, item.route!);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 22,
                      color: isSelected ? FitColors.green : FitColors.hint,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? FitColors.green : FitColors.hint,
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String? route;

  const _NavItem({
    required this.label,
    required this.icon,
    this.route,
  });
}
