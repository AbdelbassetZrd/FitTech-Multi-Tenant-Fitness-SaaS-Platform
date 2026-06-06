import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/coach_session.dart';

class StatRow extends StatelessWidget {
  const StatRow({required this.stat, required this.formatDate});

  final CoachSessionStat stat;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.courseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDate(stat.date),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            '${stat.attendanceRatePercent}% attendance',
            style: TextStyle(
              color: stat.attendanceRatePercent >= 70
                  ? AppColors.green
                  : const Color(0xFFF59E0B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
