import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/fittech_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/fit_bottom_nav_bar.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../subscription/presentation/widgets/subscription_lock_overlay.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ApiClient _apiClient = sl<ApiClient>();

  bool _isLoading = true;
  String? _errorMessage;
  _ProgressionPeriod _selectedPeriod = _ProgressionPeriod.week;
  _WorkoutProgression _progression = _WorkoutProgression.empty();
  List<_LoggedWorkout> _recentWorkouts = const [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final progressionJson =
          await _apiClient.authGet(AppConstants.workoutProgression);
      final dynamic workoutListJson =
          await _apiClient.authGet(AppConstants.workoutList);
      final rawWorkouts = workoutListJson is List
          ? List<dynamic>.from(workoutListJson)
          : List<dynamic>.from((workoutListJson['data'] as List?) ?? const []);
      final workouts = rawWorkouts
          .whereType<Map>()
          .map((item) =>
              _LoggedWorkout.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;
      setState(() {
        _progression = _WorkoutProgression.fromJson(progressionJson);
        _recentWorkouts = workouts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double get _averageWorkoutCalories {
    if (_recentWorkouts.isEmpty) return 0;
    final total = _recentWorkouts.fold<double>(
      0,
      (sum, item) => sum + item.caloriesBurned,
    );
    return total / _recentWorkouts.length;
  }

  double get _averageWorkoutMinutes {
    if (_recentWorkouts.isEmpty) return 0;
    final total = _recentWorkouts.fold<double>(
      0,
      (sum, item) => sum + item.durationMinutes,
    );
    return total / _recentWorkouts.length;
  }

  int get _currentWorkoutStreakDays {
    if (_recentWorkouts.isEmpty) return 0;
    final uniqueDates = _recentWorkouts
        .map((item) => item.parsedDay)
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (uniqueDates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final firstDate = uniqueDates.first;

    if (firstDate != today && firstDate != yesterday) {
      return 0;
    }

    var streak = 1;
    for (var index = 1; index < uniqueDates.length; index++) {
      final previous = uniqueDates[index - 1];
      final current = uniqueDates[index];
      if (previous.difference(current).inDays == 1) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  Future _loadUserSubscription() async {
    final repo = sl<AuthRepository>();
    final result = await repo.getProfile();
    return result.fold((_) => null, (user) => user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const FitBottomNavBar(currentIndex: 3),
      body: FitBackground(
        child: FutureBuilder(
          future: _loadUserSubscription(),
          builder: (context, userSnapshot) {
            final user = userSnapshot.data;
            final hasSubscription = user?.hasActiveSubscription ?? false;

            return SafeArea(
              child: Stack(
                children: [
                  RefreshIndicator(
                    color: FitColors.green,
                    backgroundColor: FitColors.surface,
                    onRefresh: _loadProgress,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                      children: [
                        Row(
                          children: [
                            _TopActionButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Workout Progress',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _TopActionButton(
                              icon: Icons.refresh_rounded,
                              onTap: _loadProgress,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 80),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: FitColors.green),
                            ),
                          )
                        else ...[
                          if (_errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF171F33),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: FitColors.label,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          _ProgressionStrip(progression: _progression),
                          const SizedBox(height: 14),
                          _ProgressAnalyticsCard(
                            progression: _progression,
                            selectedPeriod: _selectedPeriod,
                            totalWorkouts: _recentWorkouts.length,
                            averageCalories: _averageWorkoutCalories,
                            averageDurationMinutes: _averageWorkoutMinutes,
                            currentStreakDays: _currentWorkoutStreakDays,
                            onPeriodChanged: (period) {
                              setState(() => _selectedPeriod = period);
                            },
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'RECENT LOGGED WORKOUTS',
                            style: TextStyle(
                              color: FitColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_recentWorkouts.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF171F33),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Text(
                                'No workout history yet. Finish a workout to see your progress curves here.',
                                style: TextStyle(
                                  color: FitColors.label,
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                            )
                          else
                            ..._recentWorkouts
                                .take(8)
                                .map(
                                  (workout) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _LoggedWorkoutTile(workout: workout),
                                  ),
                                )
                                .toList(),
                        ],
                      ],
                    ),
                  ),
                  if (!hasSubscription)
                    SubscriptionLockOverlay(
                      onSubscribePressed: () =>
                          Navigator.pushNamed(context, '/subscription'),
                      title: 'Progress Locked',
                      message:
                          'Subscribe to view your progress analytics and history',
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

enum _ProgressionPeriod { day, week, month }

class _WorkoutMetric {
  final double calories;
  final double durationMinutes;

  const _WorkoutMetric({required this.calories, required this.durationMinutes});

  factory _WorkoutMetric.fromJson(Map<String, dynamic> json) {
    return _WorkoutMetric(
      calories: _toDouble(json['calories']),
      durationMinutes: _toDouble(json['duration_minutes']),
    );
  }

  const _WorkoutMetric.empty()
      : calories = 0,
        durationMinutes = 0;
}

class _ProgressionPoint {
  final String label;
  final double calories;
  final double durationMinutes;

  const _ProgressionPoint({
    required this.label,
    required this.calories,
    required this.durationMinutes,
  });

  factory _ProgressionPoint.fromJson(Map<String, dynamic> json) {
    return _ProgressionPoint(
      label: json['label']?.toString() ?? '',
      calories: _toDouble(json['calories']),
      durationMinutes: _toDouble(json['duration_minutes']),
    );
  }
}

class _WorkoutProgression {
  final _WorkoutMetric day;
  final _WorkoutMetric week;
  final _WorkoutMetric month;
  final List<_ProgressionPoint> dayCurve;
  final List<_ProgressionPoint> weekCurve;
  final List<_ProgressionPoint> monthCurve;

  const _WorkoutProgression({
    required this.day,
    required this.week,
    required this.month,
    required this.dayCurve,
    required this.weekCurve,
    required this.monthCurve,
  });

  factory _WorkoutProgression.fromJson(Map<String, dynamic> json) {
    return _WorkoutProgression(
      day: _WorkoutMetric.fromJson(
        Map<String, dynamic>.from(json['day'] as Map? ?? const {}),
      ),
      week: _WorkoutMetric.fromJson(
        Map<String, dynamic>.from(json['week'] as Map? ?? const {}),
      ),
      month: _WorkoutMetric.fromJson(
        Map<String, dynamic>.from(json['month'] as Map? ?? const {}),
      ),
      dayCurve: ((json['day_curve'] as List?) ?? const [])
          .map((item) => _ProgressionPoint.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList(),
      weekCurve: ((json['week_curve'] as List?) ?? const [])
          .map((item) => _ProgressionPoint.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList(),
      monthCurve: ((json['month_curve'] as List?) ?? const [])
          .map((item) => _ProgressionPoint.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  factory _WorkoutProgression.empty() => const _WorkoutProgression(
        day: _WorkoutMetric.empty(),
        week: _WorkoutMetric.empty(),
        month: _WorkoutMetric.empty(),
        dayCurve: <_ProgressionPoint>[],
        weekCurve: <_ProgressionPoint>[],
        monthCurve: <_ProgressionPoint>[],
      );

  List<_ProgressionPoint> curveFor(_ProgressionPeriod period) {
    switch (period) {
      case _ProgressionPeriod.day:
        return dayCurve;
      case _ProgressionPeriod.week:
        return weekCurve;
      case _ProgressionPeriod.month:
        return monthCurve;
    }
  }
}

class _LoggedWorkout {
  final String id;
  final String day;
  final String startTime;
  final String endTime;
  final double caloriesBurned;
  final int exerciseCount;

  const _LoggedWorkout({
    required this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.caloriesBurned,
    required this.exerciseCount,
  });

  factory _LoggedWorkout.fromJson(Map<String, dynamic> json) {
    final exercises = (json['exercises'] as List<dynamic>? ?? const []).length;
    return _LoggedWorkout(
      id: json['id']?.toString() ?? '',
      day: json['day']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      caloriesBurned: _toDouble(json['calories_burned']),
      exerciseCount: exercises,
    );
  }

  DateTime? get parsedDay => DateTime.tryParse(day);

  double get durationMinutes {
    final start = _parseTimeOnDay(startTime, parsedDay);
    final end = _parseTimeOnDay(endTime, parsedDay);
    if (start == null || end == null) return 0;
    if (end.isAfter(start)) return end.difference(start).inMinutes.toDouble();
    return end
        .add(const Duration(days: 1))
        .difference(start)
        .inMinutes
        .toDouble();
  }
}

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _TopActionButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF171F33),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

class _ProgressionStrip extends StatelessWidget {
  final _WorkoutProgression progression;

  const _ProgressionStrip({required this.progression});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _ProgressionCard(label: 'Today', metric: progression.day)),
        const SizedBox(width: 10),
        Expanded(
            child: _ProgressionCard(label: 'Week', metric: progression.week)),
        const SizedBox(width: 10),
        Expanded(
            child: _ProgressionCard(label: 'Month', metric: progression.month)),
      ],
    );
  }
}

class _ProgressionCard extends StatelessWidget {
  final String label;
  final _WorkoutMetric metric;

  const _ProgressionCard({required this.label, required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2236),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: FitColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Text(
            '${metric.calories.toStringAsFixed(0)} kcal',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${metric.durationMinutes.toStringAsFixed(0)} min',
            style: const TextStyle(color: FitColors.label, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProgressAnalyticsCard extends StatelessWidget {
  final _WorkoutProgression progression;
  final _ProgressionPeriod selectedPeriod;
  final double averageCalories;
  final double averageDurationMinutes;
  final int totalWorkouts;
  final int currentStreakDays;
  final ValueChanged<_ProgressionPeriod> onPeriodChanged;

  const _ProgressAnalyticsCard({
    required this.progression,
    required this.selectedPeriod,
    required this.averageCalories,
    required this.averageDurationMinutes,
    required this.totalWorkouts,
    required this.currentStreakDays,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final points = progression.curveFor(selectedPeriod);
    final bestPoint = _bestPoint(points, selectedPeriod);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171F33),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROGRESS ANALYTICS',
                      style: TextStyle(
                        color: FitColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Calories burned and time spent by day, week, and month from the backend progression API.',
                      style: TextStyle(
                        color: FitColors.label,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _InsightBadge(label: 'Streak', value: '$currentStreakDays d'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: _ProgressionPeriod.values
                .map(
                  (period) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PeriodChip(
                      label: _progressionPeriodLabel(period),
                      selected: selectedPeriod == period,
                      onTap: () => onPeriodChanged(period),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _CurvePanel(
            title: 'Kcal Burned',
            valueLabel:
                '${_curveTotal(points, (item) => item.calories).toStringAsFixed(0)} kcal',
            accent: FitColors.green,
            points: points,
            valueBuilder: (item) => item.calories,
          ),
          const SizedBox(height: 12),
          _CurvePanel(
            title: 'Workout Time',
            valueLabel:
                '${_curveTotal(points, (item) => item.durationMinutes).toStringAsFixed(0)} min',
            accent: const Color(0xFF60A5FA),
            points: points,
            valueBuilder: (item) => item.durationMinutes,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AnalyticsMiniCard(
                  label: 'Total workouts', value: '$totalWorkouts'),
              _AnalyticsMiniCard(
                  label: 'Avg kcal', value: averageCalories.toStringAsFixed(0)),
              _AnalyticsMiniCard(
                  label: 'Avg minutes',
                  value: averageDurationMinutes.toStringAsFixed(0)),
              _AnalyticsMiniCard(label: 'Peak period', value: bestPoint),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? FitColors.green.withValues(alpha: 0.16)
              : const Color(0xFF1B2236),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? FitColors.green.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? FitColors.green : FitColors.label,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CurvePanel extends StatelessWidget {
  final String title;
  final String valueLabel;
  final Color accent;
  final List<_ProgressionPoint> points;
  final double Function(_ProgressionPoint item) valueBuilder;

  const _CurvePanel({
    required this.title,
    required this.valueLabel,
    required this.accent,
    required this.points,
    required this.valueBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2236),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: points.isEmpty
                ? const Center(
                    child: Text(
                      'No workout data yet.',
                      style: TextStyle(color: FitColors.label, fontSize: 13),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: _LineChartPainter(
                            points: points,
                            accent: accent,
                            valueBuilder: valueBuilder,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: points
                            .map(
                              (point) => Expanded(
                                child: Text(
                                  point.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FitColors.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_ProgressionPoint> points;
  final Color accent;
  final double Function(_ProgressionPoint item) valueBuilder;

  const _LineChartPainter({
    required this.points,
    required this.accent,
    required this.valueBuilder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 10.0;
    const verticalPadding = 12.0;
    final chartWidth = size.width - (horizontalPadding * 2);
    final chartHeight = size.height - (verticalPadding * 2);
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final values = points.map(valueBuilder).toList();
    final maxValue = math.max(1.0, values.fold<double>(0, math.max));

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = verticalPadding + ((chartHeight / 3) * i);
      canvas.drawLine(
        Offset(horizontalPadding, y),
        Offset(size.width - horizontalPadding, y),
        gridPaint,
      );
    }

    final path = Path();
    final fillPath = Path();
    for (var index = 0; index < points.length; index++) {
      final dx = points.length == 1
          ? size.width / 2
          : horizontalPadding + ((chartWidth / (points.length - 1)) * index);
      final normalized = valueBuilder(points[index]) / maxValue;
      final dy = verticalPadding + chartHeight - (normalized * chartHeight);
      final point = Offset(dx, dy);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
        fillPath.moveTo(point.dx, size.height - verticalPadding);
        fillPath.lineTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
        fillPath.lineTo(point.dx, point.dy);
      }
    }

    if (points.isNotEmpty) {
      final lastDx = points.length == 1
          ? size.width / 2
          : horizontalPadding +
              ((chartWidth / (points.length - 1)) * (points.length - 1));
      fillPath.lineTo(lastDx, size.height - verticalPadding);
      fillPath.close();
    }

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.32),
          accent.withValues(alpha: 0.02)
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = accent;
    final dotFillPaint = Paint()..color = const Color(0xFF111723);
    for (var index = 0; index < points.length; index++) {
      final dx = points.length == 1
          ? size.width / 2
          : horizontalPadding + ((chartWidth / (points.length - 1)) * index);
      final normalized = valueBuilder(points[index]) / maxValue;
      final dy = verticalPadding + chartHeight - (normalized * chartHeight);
      canvas.drawCircle(Offset(dx, dy), 5, dotPaint);
      canvas.drawCircle(Offset(dx, dy), 2.4, dotFillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.accent != accent;
  }
}

class _AnalyticsMiniCard extends StatelessWidget {
  final String label;
  final String value;

  const _AnalyticsMiniCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2236),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: FitColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _InsightBadge extends StatelessWidget {
  final String label;
  final String value;

  const _InsightBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FitColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FitColors.green.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: FitColors.green, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LoggedWorkoutTile extends StatelessWidget {
  final _LoggedWorkout workout;

  const _LoggedWorkoutTile({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171F33),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FitColors.green.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: FitColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${workout.exerciseCount} exercises • ${workout.caloriesBurned.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${workout.day} • ${workout.startTime} → ${workout.endTime}',
                  style: const TextStyle(color: FitColors.label, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _parseTimeOnDay(String rawTime, DateTime? day) {
  if (day == null || rawTime.isEmpty) return null;
  final parts = rawTime.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  return DateTime(day.year, day.month, day.day, hour, minute, second);
}

String _progressionPeriodLabel(_ProgressionPeriod period) {
  switch (period) {
    case _ProgressionPeriod.day:
      return 'Day';
    case _ProgressionPeriod.week:
      return 'Week';
    case _ProgressionPeriod.month:
      return 'Month';
  }
}

double _curveTotal(
  List<_ProgressionPoint> points,
  double Function(_ProgressionPoint item) valueBuilder,
) {
  return points.fold<double>(0, (sum, item) => sum + valueBuilder(item));
}

String _bestPoint(
  List<_ProgressionPoint> points,
  _ProgressionPeriod selectedPeriod,
) {
  if (points.isEmpty) return 'No data';
  var best = points.first;
  for (final point in points.skip(1)) {
    if (point.calories > best.calories) {
      best = point;
    }
  }
  if (best.calories <= 0 && best.durationMinutes <= 0) {
    return 'No data';
  }
  return switch (selectedPeriod) {
    _ProgressionPeriod.day => best.label,
    _ProgressionPeriod.week => best.label,
    _ProgressionPeriod.month => best.label,
  };
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
