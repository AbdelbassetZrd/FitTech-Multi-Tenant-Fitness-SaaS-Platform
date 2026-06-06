import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/fittech_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/fit_bottom_nav_bar.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

class _Course {
  final int id;
  final String name;
  final String coachName;
  final String time;
  final String day;
  final int maxMembers;
  final int numberOfSessions;
  final bool isBooked;
  final String? bookingStatus;
  final int bookedSessionsCount;
  final int confirmedSessionsCount;
  final int waitingSessionsCount;
  final String? nextSessionDate;
  final String? salle;
  final int? durationTime;
  final int slotsAvailable;
  final double sessionPrice;

  const _Course({
    required this.id,
    required this.name,
    required this.coachName,
    required this.time,
    required this.day,
    required this.maxMembers,
    required this.numberOfSessions,
    required this.isBooked,
    required this.bookingStatus,
    required this.bookedSessionsCount,
    required this.confirmedSessionsCount,
    required this.waitingSessionsCount,
    required this.nextSessionDate,
    required this.salle,
    required this.durationTime,
    required this.slotsAvailable,
    this.sessionPrice = 0.0,
  });

  factory _Course.fromJson(Map<String, dynamic> json) {
    return _Course(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      coachName: (json['coach_name'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      day: (json['day'] ?? '').toString(),
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 0,
      numberOfSessions: (json['number_of_sessions'] as num?)?.toInt() ?? 0,
      isBooked: (json['is_booked'] ?? false) as bool,
      bookingStatus: json['booking_status']?.toString(),
      bookedSessionsCount:
          (json['booked_sessions_count'] as num?)?.toInt() ?? 0,
      confirmedSessionsCount:
          (json['confirmed_sessions_count'] as num?)?.toInt() ?? 0,
      waitingSessionsCount:
          (json['waiting_sessions_count'] as num?)?.toInt() ?? 0,
      nextSessionDate: json['next_session_date']?.toString(),
      salle: json['salle']?.toString(),
      durationTime: (json['duration_time'] as num?)?.toInt(),
      slotsAvailable: (json['slots_available'] as num?)?.toInt() ?? 0,
      sessionPrice:
          double.tryParse(json['session_price']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class _CourseBooking {
  final int courseId;
  final String courseName;
  final String coachName;
  final String day;
  final String time;
  final int numberOfSessions;
  final int bookedSessionsCount;
  final int confirmedSessionsCount;
  final int waitingSessionsCount;
  final String status;
  final String? nextSessionDate;
  final String? salle;

  const _CourseBooking({
    required this.courseId,
    required this.courseName,
    required this.coachName,
    required this.day,
    required this.time,
    required this.numberOfSessions,
    required this.bookedSessionsCount,
    required this.confirmedSessionsCount,
    required this.waitingSessionsCount,
    required this.status,
    required this.nextSessionDate,
    required this.salle,
  });

  factory _CourseBooking.fromJson(Map<String, dynamic> json) {
    return _CourseBooking(
      courseId: (json['course_id'] as num?)?.toInt() ?? 0,
      courseName: (json['course_name'] ?? '').toString(),
      coachName: (json['coach_name'] ?? '').toString(),
      day: (json['day'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      numberOfSessions: (json['number_of_sessions'] as num?)?.toInt() ?? 0,
      bookedSessionsCount:
          (json['booked_sessions_count'] as num?)?.toInt() ?? 0,
      confirmedSessionsCount:
          (json['confirmed_sessions_count'] as num?)?.toInt() ?? 0,
      waitingSessionsCount:
          (json['waiting_sessions_count'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? '').toString(),
      nextSessionDate: json['next_session_date']?.toString(),
      salle: json['salle']?.toString(),
    );
  }
}

class _SubscriptionTeaser extends StatelessWidget {
  final VoidCallback onSubscribePressed;

  const _SubscriptionTeaser({required this.onSubscribePressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF192238),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: FitColors.green.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.lock_open_rounded, color: FitColors.green),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Starter access unlocked',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'You can book your first classes right away. Upgrade later for unlimited bookings, analytics, and priority waitlists.',
            style: TextStyle(
              color: FitColors.label,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSubscribePressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: FitColors.green,
                side: const BorderSide(color: FitColors.green),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'VIEW SUBSCRIPTION PLANS',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbsenceWarning {
  final String courseName;
  final String sessionDate;

  const _AbsenceWarning({required this.courseName, required this.sessionDate});

  factory _AbsenceWarning.fromJson(Map<String, dynamic> json) {
    return _AbsenceWarning(
      courseName: (json['course_name'] ?? '').toString(),
      sessionDate: (json['session_date'] ?? '').toString(),
    );
  }
}

class CourseBookingScreen extends StatefulWidget {
  const CourseBookingScreen({super.key});

  @override
  State<CourseBookingScreen> createState() => _CourseBookingScreenState();
}

class _CourseBookingScreenState extends State<CourseBookingScreen> {
  final ApiClient _apiClient = sl<ApiClient>();
  Future<bool>? _subFuture;

  Future<bool> _loadSubscription() async {
    final result = await sl<AuthRepository>().getProfile();
    return result.fold((_) => false, (u) => u.hasActiveSubscription);
  }

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  // Chargily course payment state
  String? _pendingTransactionId;
  int? _pendingCourseId;

  List<_Course> _courses = const [];
  List<_CourseBooking> _bookings = const [];
  List<_AbsenceWarning> _warnings = const [];
  Map<String, dynamic> _dashboard = const {};

  String _selectedDay = 'ALL';
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _subFuture = _loadSubscription();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final coursesJson = await _apiClient.authGet(AppConstants.coursesList);
      final bookingsJson =
          await _apiClient.authGet(AppConstants.myCourseBookings);
      final dashboardJson =
          await _apiClient.authGet(AppConstants.courseMemberDashboard);
      final warningsJson =
          await _apiClient.authGet(AppConstants.courseAbsenceWarnings);

      final courses = ((coursesJson['data'] ?? coursesJson) as List)
          .whereType<Map>()
          .map((item) => _Course.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      final bookings = ((bookingsJson['data'] ?? bookingsJson) as List)
          .whereType<Map>()
          .map((item) =>
              _CourseBooking.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      final warnings = ((warningsJson['data'] ?? warningsJson) as List)
          .whereType<Map>()
          .map((item) =>
              _AbsenceWarning.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _courses = courses;
        _bookings = bookings;
        _warnings = warnings;
        _dashboard = Map<String, dynamic>.from(dashboardJson);
        _isLoading = false;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Unable to load course bookings right now.';
        _isLoading = false;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _toggleBooking(_Course course) async {
    if (course.isBooked) {
      // Cancel — always free/direct
      setState(() => _isSubmitting = true);
      try {
        final response =
            await _apiClient.authPost(AppConstants.cancelCourse(course.id));
        _showSnack(response['detail']?.toString() ?? 'Booking cancelled.');
        await _loadData();
      } catch (e) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
        if (mounted) setState(() => _isSubmitting = false);
      }
      return;
    }

    if (course.sessionPrice > 0) {
      // Paid course — go through Chargily
      await _initiatePayment(course);
    } else {
      // Free course — direct booking
      setState(() => _isSubmitting = true);
      try {
        final response =
            await _apiClient.authPost(AppConstants.bookCourse(course.id));
        _showSnack(response['detail']?.toString() ?? 'Course booked!');
        await _loadData();
      } catch (e) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _initiatePayment(_Course course) async {
    setState(() => _isSubmitting = true);
    try {
      final response = await _apiClient.authPost(
        AppConstants.initiateCoursePayment(course.id),
      );
      final checkoutUrl = response['checkout_url']?.toString() ?? '';
      final transactionId = response['transaction_id']?.toString() ?? '';
      if (checkoutUrl.isEmpty) {
        _showSnack('Could not initiate payment.');
        setState(() => _isSubmitting = false);
        return;
      }
      _pendingTransactionId = transactionId;
      _pendingCourseId = course.id;
      setState(() => _isSubmitting = false);
      _openPaymentWebView(checkoutUrl);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openPaymentWebView(String checkoutUrl) {
    // Use Chrome Custom Tabs (in-app browser) instead of WebView for better compatibility
    _openInAppBrowser(checkoutUrl);
  }

  Future<void> _openInAppBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      // Open in external browser (Chrome, Safari, etc.)
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      // Show confirmation dialog when user returns to app
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E2235),
          title: const Text(
            'Payment Complete?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Did you complete the payment in the browser?\n\nTap "Verify" to confirm your booking.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                if (_pendingTransactionId != null && _pendingCourseId != null) {
                  _verifyCoursePayment(
                      _pendingTransactionId!, _pendingCourseId!);
                }
              },
              child: const Text('Verify Payment'),
            ),
          ],
        ),
      );
    } else {
      _showSnack('Could not open browser. Please try again.');
    }
  }

  Future<void> _verifyCoursePayment(String transactionId, int courseId) async {
    setState(() => _isSubmitting = true);
    try {
      final response = await _apiClient.authPost(
        AppConstants.verifyCoursePayment,
        body: {'transaction_id': transactionId, 'course_id': courseId},
      );
      _showSnack(
          response['detail']?.toString() ?? 'Course booked successfully!');
      _pendingTransactionId = null;
      _pendingCourseId = null;
      await _loadData();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> get _dayFilters {
    final values = <String>{'ALL'};
    for (final course in _courses) {
      values.add(course.day);
    }
    return values.toList();
  }

  List<String> get _categories {
    final values = <String>{'ALL'};
    for (final course in _courses) {
      values.add(_categoryForName(course.name));
    }
    return values.toList();
  }

  List<_Course> get _filteredCourses {
    return _courses.where((course) {
      final matchesDay = _selectedDay == 'ALL' || course.day == _selectedDay;
      final matchesCategory = _selectedCategory == 'ALL' ||
          _categoryForName(course.name) == _selectedCategory;
      return matchesDay && matchesCategory;
    }).toList();
  }

  String _categoryForName(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('CROSSFIT')) return 'CROSSFIT';
    if (upper.contains('HIIT')) return 'HIIT';
    if (upper.contains('POWER') || upper.contains('STRENGTH'))
      return 'STRENGTH';
    if (upper.contains('YOGA') || upper.contains('MOBILITY')) return 'RECOVERY';
    return upper.split(' ').first;
  }

  String _levelForName(String name) {
    switch (_categoryForName(name)) {
      case 'CROSSFIT':
        return 'ADVANCED';
      case 'HIIT':
        return 'INTERMEDIATE';
      case 'STRENGTH':
        return 'STRENGTH';
      default:
        return 'RECOVERY';
    }
  }

  Color _accentForLevel(String level) {
    switch (level) {
      case 'ADVANCED':
        return FitColors.green;
      case 'INTERMEDIATE':
        return const Color(0xFF60A5FA);
      case 'STRENGTH':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFFA78BFA);
    }
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return '--:--';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final twelve = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${twelve.toString().padLeft(2, '0')}:$minute $suffix';
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'TBA';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const FitBottomNavBar(currentIndex: 2),
      body: FitBackground(
        child: FutureBuilder<bool>(
          future: _subFuture,
          builder: (context, subSnap) {
            final hasSubscription =
                subSnap.connectionState == ConnectionState.done &&
                    (subSnap.data ?? false);
            return SafeArea(
              child: Stack(
                children: [
                  _isLoading
                      ? const Center(
                          child:
                              CircularProgressIndicator(color: FitColors.green),
                        )
                      : _error != null
                          ? _ErrorState(message: _error!, onRetry: _loadData)
                          : RefreshIndicator(
                              color: FitColors.green,
                              backgroundColor: FitColors.surface,
                              onRefresh: _loadData,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _Header(
                                      weeklySessions:
                                          (_dashboard['weekly_sessions']
                                                      as num?)
                                                  ?.toInt() ??
                                              0,
                                      bookedCourses: _bookings.length,
                                      warnings: _warnings.length,
                                    ),
                                    const SizedBox(height: 18),
                                    if (!hasSubscription &&
                                        subSnap.connectionState ==
                                            ConnectionState.done) ...[
                                      _SubscriptionTeaser(
                                        onSubscribePressed: () =>
                                            Navigator.pushNamed(
                                                context, '/subscription'),
                                      ),
                                      const SizedBox(height: 18),
                                    ],
                                    _FilterChips(
                                      values: _dayFilters,
                                      selected: _selectedDay,
                                      onChanged: (value) =>
                                          setState(() => _selectedDay = value),
                                    ),
                                    const SizedBox(height: 12),
                                    _FilterChips(
                                      values: _categories,
                                      selected: _selectedCategory,
                                      onChanged: (value) => setState(
                                          () => _selectedCategory = value),
                                    ),
                                    const SizedBox(height: 16),
                                    if (_warnings.isNotEmpty) ...[
                                      _WarningsCard(warnings: _warnings),
                                      const SizedBox(height: 16),
                                    ],
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'COURSES',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          '${_filteredCourses.length} COURSES FOUND',
                                          style: const TextStyle(
                                            color: FitColors.label,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (_filteredCourses.isEmpty)
                                      const _EmptyCard(
                                          message:
                                              'No courses match the selected filters.')
                                    else
                                      ..._filteredCourses.map(
                                        (course) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 14),
                                          child: _CourseCard(
                                            course: course,
                                            level: _levelForName(course.name),
                                            accent: _accentForLevel(
                                                _levelForName(course.name)),
                                            isBusy: _isSubmitting,
                                            onTap: () => _toggleBooking(course),
                                            formatTime: _formatTime,
                                            formatDate: _formatDate,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'MY BOOKINGS',
                                      style: TextStyle(
                                        color: FitColors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (_bookings.isEmpty)
                                      const _EmptyCard(
                                          message:
                                              'You have no course bookings yet.')
                                    else
                                      ..._bookings.map(
                                        (booking) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: _BookingCard(
                                            booking: booking,
                                            formatTime: _formatTime,
                                            formatDate: _formatDate,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int weeklySessions;
  final int bookedCourses;
  final int warnings;

  const _Header({
    required this.weeklySessions,
    required this.bookedCourses,
    required this.warnings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'BOOK COURSES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2436),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_outline, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
                child: _MiniStatCard(
                    label: 'THIS WEEK', value: '$weeklySessions')),
            const SizedBox(width: 10),
            Expanded(
                child: _MiniStatCard(label: 'BOOKED', value: '$bookedCourses')),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStatCard(
                label: 'WARNINGS',
                value: '$warnings',
                valueColor:
                    warnings == 0 ? FitColors.green : const Color(0xFFF97316),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MiniStatCard({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2436),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: FitColors.label,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterChips({
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = values[index];
          final isSelected = value == selected;
          return GestureDetector(
            onTap: () => onChanged(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? FitColors.green : const Color(0xFF1A2031),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: isSelected ? Colors.white : FitColors.label,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  final List<_AbsenceWarning> warnings;

  const _WarningsCard({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3B2218),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ABSENCE WARNINGS',
            style: TextStyle(
              color: Color(0xFFF97316),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          ...warnings.take(2).map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${warning.courseName} • ${warning.sessionDate}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final _Course course;
  final String level;
  final Color accent;
  final bool isBusy;
  final VoidCallback onTap;
  final String Function(String raw) formatTime;
  final String Function(String? raw) formatDate;

  const _CourseCard({
    required this.course,
    required this.level,
    required this.accent,
    required this.isBusy,
    required this.onTap,
    required this.formatTime,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final progress = course.maxMembers == 0
        ? 0.0
        : ((course.maxMembers - course.slotsAvailable) / course.maxMembers)
            .clamp(0.0, 1.0);
    final isPaid = course.sessionPrice > 0;
    final actionLabel = course.isBooked
        ? 'CANCEL COURSE'
        : isPaid
            ? 'PAY & BOOK  •  ${course.sessionPrice.toStringAsFixed(0)} DA/session'
            : 'BOOK ${course.numberOfSessions} SESSIONS';
    final actionColor = course.isBooked ? Colors.white : FitColors.green;
    final actionText = course.isBooked ? const Color(0xFF1A2031) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2436),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              if (isPaid && !course.isBooked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${course.sessionPrice.toStringAsFixed(0)} DA',
                    style: const TextStyle(
                      color: Color(0xFFF97316),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: course.isBooked
                      ? FitColors.green.withOpacity(0.16)
                      : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  course.isBooked
                      ? Icons.check_rounded
                      : (isPaid ? Icons.payment_rounded : Icons.bolt_rounded),
                  color: course.isBooked ? FitColors.green : FitColors.label,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            course.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 14, color: FitColors.label),
              const SizedBox(width: 6),
              Text(
                formatTime(course.time),
                style: const TextStyle(color: FitColors.label, fontSize: 12),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.person_outline_rounded,
                  size: 14, color: FitColors.label),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  course.coachName,
                  style: const TextStyle(color: FitColors.label, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${course.numberOfSessions} sessions • ${course.day} • next ${formatDate(course.nextSessionDate)}',
            style: const TextStyle(color: FitColors.label, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            '${course.salle ?? 'Gym Room'} • ${(course.durationTime ?? 60)} min',
            style: const TextStyle(color: FitColors.hint, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Text(
            course.isBooked
                ? 'YOUR BOOKING: ${course.bookedSessionsCount}/${course.numberOfSessions} • ${course.bookingStatus?.toUpperCase() ?? 'BOOKED'}'
                : '${course.slotsAvailable} SLOTS AVAILABLE',
            style: TextStyle(
              color: course.isBooked ? FitColors.green : accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${course.maxMembers - course.slotsAvailable}/${course.maxMembers}',
                style: const TextStyle(color: FitColors.hint, fontSize: 10),
              ),
              const Spacer(),
              if (course.isBooked)
                Text(
                  '${course.confirmedSessionsCount} confirmed • ${course.waitingSessionsCount} waiting',
                  style: const TextStyle(color: FitColors.hint, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isBusy ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: actionText,
                disabledBackgroundColor: actionColor.withOpacity(0.5),
                disabledForegroundColor: actionText.withOpacity(0.75),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isBusy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: actionText,
                      ),
                    )
                  : Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final _CourseBooking booking;
  final String Function(String raw) formatTime;
  final String Function(String? raw) formatDate;

  const _BookingCard({
    required this.booking,
    required this.formatTime,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2031),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: booking.status == 'confirmed'
                  ? FitColors.green
                  : const Color(0xFFF97316),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.courseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${booking.bookedSessionsCount}/${booking.numberOfSessions} sessions • ${booking.status.toUpperCase()}',
                  style: const TextStyle(color: FitColors.label, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  '${booking.day} • ${formatTime(booking.time)} • next ${formatDate(booking.nextSessionDate)}',
                  style: const TextStyle(color: FitColors.hint, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2436),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: FitColors.label, fontSize: 14),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: FitColors.hint, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 14),
            FitPrimaryButton(label: 'TRY AGAIN', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
