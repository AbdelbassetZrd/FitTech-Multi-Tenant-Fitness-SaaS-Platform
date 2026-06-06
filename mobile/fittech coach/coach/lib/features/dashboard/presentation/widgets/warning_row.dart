import 'package:flutter/material.dart';
import '../../../../core/models/coach_session.dart';

class WarningRow extends StatelessWidget {
  const WarningRow({required this.warning});

  final AbsenceWarning warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1A12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${warning.courseName} • ${warning.sessionDate}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
