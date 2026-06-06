import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/coach_session.dart';

class SessionSummaryCard extends StatelessWidget {
  const SessionSummaryCard({
    required this.session,
    required this.selected,
    required this.formatDate,
    required this.formatTime,
    required this.onTap,
  });

  final CoachSession session;
  final bool selected;
  final String Function(DateTime) formatDate;
  final String Function(String) formatTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF132740) : AppColors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.green
                : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: session.attendanceMarked
                    ? AppColors.green.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                session.attendanceMarked ? 'VALIDATED' : session.statusLabel,
                style: TextStyle(
                  color: session.attendanceMarked
                      ? AppColors.green
                      : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              session.courseName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            Text(
              '${formatDate(session.date)} • ${formatTime(session.time)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              '${session.confirmedCount}/${session.maxMembers} members • ${session.salle}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
