import 'package:flutter/material.dart';
import '../../../../core/network/coach_api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/theme/app_colors.dart';

class AttendanceScreen extends StatefulWidget {
  final int sessionId;
  final List<dynamic> bookings;
  const AttendanceScreen({
    super.key,
    required this.sessionId,
    required this.bookings,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _api = CoachApiClient();
  bool _loading = true;
  String? _error;
  List<dynamic> _bookings = [];
  Set<String> _presentMemberIds = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize with bookings from argument
    setState(() {
      _bookings = widget.bookings;
      _loading = false;
    });
  }

  Future<void> _submitAttendance() async {
    if (_presentMemberIds.isEmpty && _bookings.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member as present'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await _api.post(
        ApiPaths.attendance(widget.sessionId),
        requiresAuth: true,
        body: {'present_member_ids': _presentMemberIds.toList()},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['detail']?.toString() ??
                'Attendance marked for ${_presentMemberIds.length} members',
          ),
          backgroundColor: AppColors.green,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  void _toggleMember(String memberId) {
    setState(() {
      if (_presentMemberIds.contains(memberId)) {
        _presentMemberIds.remove(memberId);
      } else {
        _presentMemberIds.add(memberId);
      }
    });
  }

  void _markAllPresent() {
    setState(() {
      _presentMemberIds.clear();
      for (final booking in _bookings) {
        _presentMemberIds.add(booking['member_id']?.toString() ?? '');
      }
    });
  }

  void _clearAll() {
    setState(() => _presentMemberIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: const Color(0xFF09101D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF09101D), Color(0xFF101A2E), Color(0xFF0A1220)],
          ),
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.green),
              )
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: AppColors.green, size: 60),
                    const SizedBox(height: 16),
                    Text('Error: $_error', textAlign: TextAlign.center),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Session Info Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1A2437), Color(0xFF131D31)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Details',
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Session ID:',
                                style: TextStyle(color: AppColors.muted),
                              ),
                              Text(
                                '${widget.sessionId}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Members to mark:',
                                style: TextStyle(color: AppColors.muted),
                              ),
                              Text(
                                '${_bookings.length}',
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _markAllPresent,
                            icon: const Icon(Icons.done_all),
                            label: const Text('Mark All Present'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.green,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearAll,
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Clear'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Members List Header
                    const Text(
                      'ATTENDANCE LIST',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Members List (Mock Data)
                    if (_bookings.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: AppColors.muted,
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No members booked for this session',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          final memberId =
                              booking['member']?.toString() ??
                              booking['member_id']?.toString() ??
                              '$index';
                          final memberName =
                              booking['member_name'] ??
                              booking['name'] ??
                              'Member $index';
                          final memberEmail =
                              booking['member_email'] ?? 'No email';
                          final isPresent = _presentMemberIds.contains(
                            memberId,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isPresent
                                    ? AppColors.green.withValues(alpha: 0.12)
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPresent
                                      ? AppColors.green
                                      : AppColors.green.withValues(alpha: 0.2),
                                ),
                              ),
                              child: CheckboxListTile(
                                title: Text(
                                  memberName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  memberEmail,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                value: isPresent,
                                onChanged: (_) => _toggleMember(memberId),
                                activeColor: AppColors.green,
                                checkColor: Colors.black,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),

                    // Warning Info
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFF59E0B),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Warning Policy',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Absent members (not marked present) will receive 1 warning. 3 warnings = 1 week suspension.',
                            style: TextStyle(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.8),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submitAttendance,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.green,
                          disabledBackgroundColor: AppColors.green.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'SUBMIT ATTENDANCE',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
