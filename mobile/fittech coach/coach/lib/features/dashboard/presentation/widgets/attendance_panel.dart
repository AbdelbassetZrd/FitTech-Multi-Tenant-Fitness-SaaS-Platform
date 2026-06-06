import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/panel.dart';
import '../../../../core/models/coach_session.dart';

class AttendancePanel extends StatelessWidget {
  const AttendancePanel({
    required this.session,
    required this.canValidate,
    required this.selectedMemberIds,
    required this.isSubmitting,
    required this.formatDate,
    required this.formatTime,
    required this.onToggleMember,
    required this.onMarkAll,
    required this.onClear,
    required this.onSubmit,
  });

  final CoachSession session;
  final bool canValidate;
  final Set<String> selectedMemberIds;
  final bool isSubmitting;
  final String Function(DateTime) formatDate;
  final String Function(String) formatTime;
  final void Function(String memberId, bool selected) onToggleMember;
  final VoidCallback onMarkAll;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Attendance Board',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.courseName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${formatDate(session.date)} • ${formatTime(session.time)} • ${session.salle}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: canValidate && !isSubmitting ? onSubmit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        session.attendanceMarked ? 'Validated' : 'Validate All',
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              InlineStat(
                label: 'Confirmed',
                value: '${session.confirmedCount}',
              ),
              const SizedBox(width: 16),
              InlineStat(label: 'Waiting', value: '${session.waitingCount}'),
              const SizedBox(width: 16),
              InlineStat(
                label: 'Selected',
                value: '${selectedMemberIds.length}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: canValidate ? onMarkAll : null,
                child: const Text('Mark all present'),
              ),
              TextButton(
                onPressed: canValidate ? onClear : null,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (session.confirmedBookings.isEmpty)
            const Text(
              'No confirmed members for this session.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            ...session.confirmedBookings.map(
              (booking) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1628),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CheckboxListTile(
                  value: selectedMemberIds.contains(booking.memberId),
                  onChanged: canValidate
                      ? (value) =>
                            onToggleMember(booking.memberId, value ?? false)
                      : null,
                  activeColor: AppColors.green,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text(
                    booking.memberName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    booking.memberEmail,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
              ),
            ),
          if (session.waitingBookings.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Waiting list',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...session.waitingBookings.map(
              (booking) => ListTile(
                tileColor: const Color(0xFF0E1628),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                title: Text(booking.memberName),
                subtitle: Text(booking.memberEmail),
                trailing: const Text(
                  'WAITING',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class InlineStat extends StatelessWidget {
  const InlineStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
