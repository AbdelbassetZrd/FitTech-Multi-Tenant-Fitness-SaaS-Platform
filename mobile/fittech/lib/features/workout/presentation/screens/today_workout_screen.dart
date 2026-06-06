import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/fittech_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/fit_bottom_nav_bar.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../subscription/presentation/widgets/subscription_lock_overlay.dart';
import 'exercise_pose_monitor_screen.dart';

class TodayWorkoutScreen extends StatefulWidget {
  const TodayWorkoutScreen({super.key});

  @override
  State<TodayWorkoutScreen> createState() => _TodayWorkoutScreenState();
}

class _TodayWorkoutScreenState extends State<TodayWorkoutScreen> {
  final ApiClient _apiClient = sl<ApiClient>();

  int _selectedBodyPartIndex = 0;
  ExerciseEquipmentFilter _equipmentFilter = ExerciseEquipmentFilter.all;
  bool _isLoading = true;
  bool _isSavingWorkout = false;
  String? _errorMessage;
  Future<dynamic>? _subscriptionFuture;
  List<_ExerciseItem> _apiExercises = const [];
  List<_LoggedWorkout> _recentWorkouts = const [];
  List<_PlannedExercise> _todayWorkout = const [];

  static const List<_BodyPartFilter> _bodyParts = [
    _BodyPartFilter(
        label: 'Chest',
        apiValue: 'chest',
        icon: Icons.favorite_outline_rounded),
    _BodyPartFilter(
        label: 'Shoulders',
        apiValue: 'shoulders',
        icon: Icons.accessibility_new_rounded),
    _BodyPartFilter(
        label: 'Arms', apiValue: 'upper arms', icon: Icons.sports_mma_outlined),
    _BodyPartFilter(
        label: 'Back', apiValue: 'back', icon: Icons.airline_seat_flat_rounded),
    _BodyPartFilter(
        label: 'Legs',
        apiValue: 'upper legs',
        icon: Icons.directions_run_rounded),
  ];

  static const List<_ExerciseItem> _fallbackExercises = [
    _ExerciseItem(
      id: '0025',
      name: 'Barbell Bench Press',
      bodyPart: 'chest',
      equipmentLabel: 'barbell',
      target: 'pectorals',
      instructions: [
        'Lie flat on a bench with your feet planted on the floor.',
        'Lower the bar to your chest with control.',
        'Press the bar back up until your arms are fully extended.',
      ],
    ),
    _ExerciseItem(
      id: '1313',
      name: 'Push-Up',
      bodyPart: 'chest',
      equipmentLabel: 'body weight',
      target: 'pectorals',
      instructions: [
        'Start in a plank position with hands slightly wider than shoulders.',
        'Lower your chest toward the floor.',
        'Press back up while keeping your body straight.',
      ],
    ),
    _ExerciseItem(
      id: '0405',
      name: 'Dumbbell Lateral Raise',
      bodyPart: 'shoulders',
      equipmentLabel: 'dumbbell',
      target: 'delts',
      instructions: [
        'Raise the dumbbells out to your sides.',
        'Lift to shoulder height without shrugging.',
        'Lower slowly and repeat.',
      ],
    ),
    _ExerciseItem(
      id: '3293',
      name: 'Pike Push-Up',
      bodyPart: 'shoulders',
      equipmentLabel: 'body weight',
      target: 'delts',
      instructions: [
        'Form an inverted V shape with your hips high.',
        'Lower your head between your hands.',
        'Push back to the starting position.',
      ],
    ),
    _ExerciseItem(
      id: '0294',
      name: 'Dumbbell Biceps Curl',
      bodyPart: 'upper arms',
      equipmentLabel: 'dumbbell',
      target: 'biceps',
      instructions: [
        'Hold the dumbbells by your sides.',
        'Curl both weights toward your shoulders.',
        'Lower with control.',
      ],
    ),
    _ExerciseItem(
      id: '1776',
      name: 'Diamond Push-Up',
      bodyPart: 'upper arms',
      equipmentLabel: 'body weight',
      target: 'triceps',
      instructions: [
        'Place your hands together under your chest.',
        'Lower down while keeping elbows close.',
        'Push back up strongly.',
      ],
    ),
    _ExerciseItem(
      id: '0687',
      name: 'Seated Cable Row',
      bodyPart: 'back',
      equipmentLabel: 'cable',
      target: 'lats',
      instructions: [
        'Sit tall and grasp the cable handle.',
        'Pull the handle toward your torso.',
        'Squeeze your back before returning.',
      ],
    ),
    _ExerciseItem(
      id: '1429',
      name: 'Pull-Up',
      bodyPart: 'back',
      equipmentLabel: 'body weight',
      target: 'lats',
      instructions: [
        'Hang from the bar with a firm grip.',
        'Pull your chest upward.',
        'Lower with control.',
      ],
    ),
    _ExerciseItem(
      id: '0059',
      name: 'Barbell Squat',
      bodyPart: 'upper legs',
      equipmentLabel: 'barbell',
      target: 'quads',
      instructions: [
        'Stand with the barbell on your upper back.',
        'Sit your hips back and squat down.',
        'Drive through your heels to stand.',
      ],
    ),
    _ExerciseItem(
      id: '3594',
      name: 'Walking Lunge',
      bodyPart: 'upper legs',
      equipmentLabel: 'body weight',
      target: 'quads',
      instructions: [
        'Step forward into a deep lunge.',
        'Push through the front leg to step forward again.',
        'Alternate sides as you move.',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refreshScreen();
  }

  Future<void> _refreshScreen() async {
    await Future.wait([
      _loadExercises(showLoader: true),
      _loadWorkoutInsights(),
    ]);
  }

  Future<void> _loadWorkoutInsights() async {
    try {
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
        _recentWorkouts = workouts;
      });
    } catch (_) {}
  }

  Future<void> _loadExercises({bool showLoader = false}) async {
    final bodyPart = _bodyParts[_selectedBodyPartIndex];
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    if (AppConstants.exerciseDbKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        _apiExercises = _fallbackExercises
            .where((exercise) => exercise.bodyPart == bodyPart.apiValue)
            .toList();
        _isLoading = false;
        _errorMessage =
            'ExerciseDB key is missing. Showing local basic plan exercises for now.';
      });
      return;
    }

    try {
      final uri = Uri.parse(
        '${AppConstants.exerciseDbBaseUrl}/exercises/bodyPart/${Uri.encodeComponent(bodyPart.apiValue)}?limit=18',
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-rapidapi-host': AppConstants.exerciseDbHost,
          'x-rapidapi-key': AppConstants.exerciseDbKey,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('ExerciseDB returned ${response.statusCode}.');
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      final exercises = decoded
          .map((item) => _ExerciseItem.fromJson(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _apiExercises = exercises;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apiExercises = _fallbackExercises
            .where((exercise) => exercise.bodyPart == bodyPart.apiValue)
            .toList();
        _isLoading = false;
        _errorMessage =
            'Could not load ExerciseDB right now. Showing fallback exercises.';
      });
    }
  }

  List<_ExerciseItem> get _visibleExercises {
    return _apiExercises.where((exercise) {
      return switch (_equipmentFilter) {
        ExerciseEquipmentFilter.all => true,
        ExerciseEquipmentFilter.withEquipment => !exercise.isBodyweight,
        ExerciseEquipmentFilter.withoutEquipment => exercise.isBodyweight,
      };
    }).toList();
  }

  double get _totalPlannedCalories => _todayWorkout.fold(
        0,
        (sum, item) => sum + item.estimatedCalories,
      );

  int get _totalPlannedSets => _todayWorkout.fold(
        0,
        (sum, item) => sum + item.sets,
      );

  int get _estimatedMinutes => _todayWorkout.fold(
        0,
        (sum, item) => sum + (item.sets * 2),
      );

  Future<void> _openExercisePlanner(_ExerciseItem exercise,
      {_PlannedExercise? existing}) async {
    final planned =
        await _showExercisePlannerSheet(context, exercise, existing: existing);
    if (planned == null || !mounted) return;

    setState(() {
      final index =
          _todayWorkout.indexWhere((item) => item.exercise.id == exercise.id);
      if (index >= 0) {
        final copy = List<_PlannedExercise>.from(_todayWorkout);
        copy[index] = planned;
        _todayWorkout = copy;
      } else {
        _todayWorkout = [..._todayWorkout, planned];
      }
    });
  }

  void _removeExercise(String exerciseId) {
    setState(() {
      _todayWorkout = _todayWorkout
          .where((item) => item.exercise.id != exerciseId)
          .toList();
    });
  }

  Future<_PlannedExercise?> _showExercisePlannerSheet(
    BuildContext context,
    _ExerciseItem exercise, {
    _PlannedExercise? existing,
  }) async {
    final setsController =
        TextEditingController(text: (existing?.sets ?? 4).toString());
    final repsController = TextEditingController(
        text: (existing?.reps ?? exercise.suggestedReps).toString());
    final weightController = TextEditingController(
      text: existing != null && existing.weightKg > 0
          ? existing.weightKg.toStringAsFixed(0)
          : '',
    );

    _PlannedExercise? result;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111723),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final sets = int.tryParse(setsController.text.trim()) ?? 4;
            final reps = int.tryParse(repsController.text.trim()) ??
                exercise.suggestedReps;
            final weight = double.tryParse(weightController.text.trim()) ?? 0;
            final preview = _PlannedExercise(
              exercise: exercise,
              sets: math.max(1, sets),
              reps: math.max(1, reps),
              weightKg: math.max(0, weight),
            );

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        exercise.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoPill(text: _capitalize(exercise.bodyPart)),
                          _InfoPill(text: _capitalize(exercise.target)),
                          _InfoPill(text: _capitalize(exercise.equipmentLabel)),
                          _InfoPill(
                              text:
                                  '${preview.estimatedCalories.toStringAsFixed(1)} kcal'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 1.25,
                          child: Container(
                            color: const Color(0xFF25212A),
                            child: _ExerciseGif(
                                exercise: exercise, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _NumberField(
                              controller: setsController,
                              label: 'Sets',
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _NumberField(
                              controller: repsController,
                              label: 'Reps',
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _NumberField(
                        controller: weightController,
                        label: exercise.requiresWeight
                            ? 'Weight (kg)'
                            : 'Weight (optional)',
                        enabled: exercise.requiresWeight,
                        hintText: exercise.requiresWeight
                            ? 'Enter target weight'
                            : 'Bodyweight exercise',
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2236),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.04)),
                        ),
                        child: const Text(
                          'Calories are calculated on the phone using body part, sets, reps, and weight. The completed workout will be sent to the backend with start time, end time, calories burned, and exercise lines.',
                          style: TextStyle(
                            color: FitColors.label,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            result = preview;
                            Navigator.of(modalContext).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FitColors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            existing == null
                                ? 'ADD TO TODAY\'S WORKOUT'
                                : 'UPDATE EXERCISE',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    setsController.dispose();
    repsController.dispose();
    weightController.dispose();
    return result;
  }

  Future<void> _startWorkout() async {
    if (_todayWorkout.isEmpty) {
      _showSnack('Select at least one exercise for today\'s workout.');
      return;
    }

    final startedAt = DateTime.now();
    final result = await Navigator.of(context).push<_CompletedWorkoutResult>(
      MaterialPageRoute(
        builder: (_) => _WorkoutSessionScreen(
          startedAt: startedAt,
          plannedExercises: _todayWorkout,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    await _submitCompletedWorkout(result);
  }

  Future<void> _submitCompletedWorkout(_CompletedWorkoutResult result) async {
    setState(() => _isSavingWorkout = true);
    try {
      await _apiClient.authPost(
        AppConstants.workoutLog,
        body: {
          'day': _formatDateOnly(result.startedAt),
          'start_time': _formatTimeOnly(result.startedAt),
          'end_time': _formatTimeOnly(result.endedAt),
          'calories_burned':
              double.parse(result.totalCalories.toStringAsFixed(2)),
          'exercises': result.completedExercises
              .map(
                (exercise) => {
                  'exercise_name': exercise.exercise.displayName,
                  'reps': exercise.reps,
                  'sets': exercise.completedSets,
                  'weight': double.parse(exercise.weightKg.toStringAsFixed(2)),
                  'notes':
                      'exercise_db_id:${exercise.exercise.id}; body_part:${exercise.exercise.bodyPart}; target:${exercise.exercise.target}; estimated_kcal:${exercise.actualCalories.toStringAsFixed(1)}',
                },
              )
              .toList(),
        },
      );

      if (!mounted) return;
      setState(() {
        _todayWorkout = const [];
      });
      await _loadWorkoutInsights();
      _showSnack(
        'Workout saved. ${result.totalCalories.toStringAsFixed(1)} kcal burned in ${result.duration.inMinutes} min.',
      );
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSavingWorkout = false);
      }
    }
  }

  Future _loadUserSubscription() async {
    final repo = sl<AuthRepository>();
    final result = await repo.getProfile();
    return result.fold((_) => null, (user) => user);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bodyPart = _bodyParts[_selectedBodyPartIndex];
    final filteredExercises = _visibleExercises;

    return Scaffold(
      bottomNavigationBar: const FitBottomNavBar(currentIndex: 1),
      body: FitBackground(
        child: FutureBuilder(
          future: _subscriptionFuture ??= _loadUserSubscription(),
          builder: (context, userSnapshot) {
            final user = userSnapshot.data;
            final hasSubscription =
                userSnapshot.connectionState == ConnectionState.done &&
                    (user?.hasActiveSubscription ?? false);

            return SafeArea(
              child: Stack(
                children: [
                  RefreshIndicator(
                    color: FitColors.green,
                    backgroundColor: FitColors.surface,
                    onRefresh: _refreshScreen,
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
                                'Today\'s Workout',
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
                              onTap: _refreshScreen,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _WorkoutSummaryCard(
                          exerciseCount: _todayWorkout.length,
                          totalSets: _totalPlannedSets,
                          totalCalories: _totalPlannedCalories,
                          estimatedMinutes: _estimatedMinutes,
                          isSaving: _isSavingWorkout,
                          onStartWorkout: _startWorkout,
                        ),
                        if (_todayWorkout.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'TODAY\'S SELECTED EXERCISES',
                            style: TextStyle(
                              color: FitColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._todayWorkout.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SelectedExerciseTile(
                                item: item,
                                onEdit: () => _openExercisePlanner(
                                    item.exercise,
                                    existing: item),
                                onRemove: () =>
                                    _removeExercise(item.exercise.id),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _bodyParts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final item = _bodyParts[index];
                              return _BodyPartChip(
                                item: item,
                                selected: index == _selectedBodyPartIndex,
                                onTap: () {
                                  setState(
                                      () => _selectedBodyPartIndex = index);
                                  _loadExercises(showLoader: true);
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: ExerciseEquipmentFilter.values
                              .map(
                                (filter) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _EquipmentChip(
                                    label: _equipmentFilterLabel(filter),
                                    icon: _equipmentFilterIcon(filter),
                                    selected: _equipmentFilter == filter,
                                    onTap: () => setState(
                                        () => _equipmentFilter = filter),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B2236),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: FitColors.label,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'EXERCISE LIBRARY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  bodyPart.label,
                                  style: const TextStyle(
                                      color: FitColors.label, fontSize: 13),
                                ),
                              ],
                            ),
                            _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: FitColors.green,
                                    ),
                                  )
                                : Text(
                                    '${filteredExercises.length}',
                                    style: const TextStyle(
                                      color: FitColors.green,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 50),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: FitColors.green),
                            ),
                          )
                        else if (filteredExercises.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'No exercises found for this body part and filter.',
                                style: TextStyle(
                                    color: FitColors.label, fontSize: 15),
                              ),
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 390;
                              return GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: compact ? 10 : 14,
                                  crossAxisSpacing: compact ? 10 : 14,
                                  childAspectRatio: compact ? 0.62 : 0.67,
                                ),
                                itemCount: filteredExercises.length,
                                itemBuilder: (context, index) {
                                  final exercise = filteredExercises[index];
                                  final planned = _todayWorkout
                                      .where((item) =>
                                          item.exercise.id == exercise.id)
                                      .firstOrNull;
                                  return _ExerciseCard(
                                    exercise: exercise,
                                    compact: compact,
                                    selected: planned != null,
                                    plannedLabel: planned == null
                                        ? null
                                        : '${planned.sets} sets • ${planned.estimatedCalories.toStringAsFixed(0)} kcal',
                                    onTap: () => _openExercisePlanner(exercise,
                                        existing: planned),
                                  );
                                },
                              );
                            },
                          ),
                        if (_recentWorkouts.isNotEmpty) ...[
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
                          ..._recentWorkouts.take(3).map(
                                (workout) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _LoggedWorkoutTile(workout: workout),
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                  if (!hasSubscription)
                    SubscriptionLockOverlay(
                      onSubscribePressed: () =>
                          Navigator.pushNamed(context, '/subscription'),
                      title: 'Workout Locked',
                      message:
                          'Unlock workout plans and training details with a subscription.',
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

enum ExerciseEquipmentFilter { all, withEquipment, withoutEquipment }

class _BodyPartFilter {
  final String label;
  final String apiValue;
  final IconData icon;

  const _BodyPartFilter({
    required this.label,
    required this.apiValue,
    required this.icon,
  });
}

class _ExerciseItem {
  final String id;
  final String name;
  final String bodyPart;
  final String equipmentLabel;
  final String target;
  final List<String> instructions;

  const _ExerciseItem({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipmentLabel,
    required this.target,
    required this.instructions,
  });

  factory _ExerciseItem.fromJson(Map<String, dynamic> json) {
    return _ExerciseItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Exercise',
      bodyPart: json['bodyPart']?.toString() ?? '',
      equipmentLabel: json['equipment']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      instructions: (json['instructions'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  bool get isBodyweight {
    final value = equipmentLabel.toLowerCase();
    return value.contains('body weight') || value.contains('bodyweight');
  }

  bool get requiresWeight => !isBodyweight;

  int get suggestedReps {
    if (bodyPart == 'upper legs' || bodyPart == 'back') return 10;
    return 12;
  }

  double estimateCalories(
      {required int sets, required int reps, required double weightKg}) {
    final base = switch (bodyPart) {
      'upper legs' => 9.5,
      'back' => 8.6,
      'chest' => 8.0,
      'shoulders' => 7.2,
      _ => 6.8,
    };
    final intensity = isBodyweight ? 1.0 : 1.18;
    final repsFactor = math.max(0.6, reps / 10);
    final weightBonus = requiresWeight ? math.min(weightKg, 150) * 0.07 : 0.0;
    final total = (sets * base * intensity * repsFactor) + weightBonus;
    return double.parse(total.toStringAsFixed(1));
  }

  String get displayName => _titleCase(name);
}

class _PlannedExercise {
  final _ExerciseItem exercise;
  final int sets;
  final int reps;
  final double weightKg;
  final int completedSets;

  const _PlannedExercise({
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.weightKg,
    this.completedSets = 0,
  });

  double get estimatedCalories =>
      exercise.estimateCalories(sets: sets, reps: reps, weightKg: weightKg);

  int get setsLeft => math.max(0, sets - completedSets);

  bool get isComplete => completedSets >= sets;

  double get actualCalories {
    if (sets == 0) return 0;
    final ratio = completedSets / sets;
    return double.parse((estimatedCalories * ratio).toStringAsFixed(1));
  }

  _PlannedExercise copyWith({
    int? sets,
    int? reps,
    double? weightKg,
    int? completedSets,
  }) {
    return _PlannedExercise(
      exercise: exercise,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      completedSets: completedSets ?? this.completedSets,
    );
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

class _WorkoutSummaryCard extends StatelessWidget {
  final int exerciseCount;
  final int totalSets;
  final double totalCalories;
  final int estimatedMinutes;
  final bool isSaving;
  final VoidCallback onStartWorkout;

  const _WorkoutSummaryCard({
    required this.exerciseCount,
    required this.totalSets,
    required this.totalCalories,
    required this.estimatedMinutes,
    required this.isSaving,
    required this.onStartWorkout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171F33),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TODAY\'S PLAN',
            style: TextStyle(
              color: FitColors.green,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Build your workout from the ExerciseDB basic plan, choose sets and weight, then start the session timer and log the result to the backend.',
            style:
                TextStyle(color: FitColors.label, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child:
                      _MiniStat(label: 'Exercises', value: '$exerciseCount')),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(label: 'Sets', value: '$totalSets')),
              const SizedBox(width: 10),
              Expanded(
                  child: _MiniStat(
                      label: 'Calories',
                      value: totalCalories.toStringAsFixed(0))),
              const SizedBox(width: 10),
              Expanded(
                  child:
                      _MiniStat(label: 'Minutes', value: '$estimatedMinutes')),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : onStartWorkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: FitColors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                isSaving ? 'SAVING WORKOUT...' : 'START WORKOUT',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(color: FitColors.muted, fontSize: 10)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SelectedExerciseTile extends StatelessWidget {
  final _PlannedExercise item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _SelectedExerciseTile({
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171F33),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 72,
              height: 72,
              child: _ExerciseGif(exercise: item.exercise),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.exercise.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.sets} sets • ${item.reps} reps • ${item.weightKg.toStringAsFixed(item.weightKg == item.weightKg.roundToDouble() ? 0 : 1)} kg',
                  style: const TextStyle(color: FitColors.label, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.estimatedCalories.toStringAsFixed(1)} kcal',
                  style: const TextStyle(
                      color: FitColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, color: Colors.white70)),
              IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BodyPartChip extends StatelessWidget {
  final _BodyPartFilter item;
  final bool selected;
  final VoidCallback onTap;

  const _BodyPartChip(
      {required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E2433) : const Color(0xFF121826),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? FitColors.green.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon,
                color: selected ? FitColors.green : FitColors.label),
            const SizedBox(height: 10),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : FitColors.label,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EquipmentChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _EquipmentChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15, color: selected ? FitColors.green : FitColors.label),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? FitColors.green : FitColors.label,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final _ExerciseItem exercise;
  final bool compact;
  final bool selected;
  final String? plannedLabel;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exercise,
    required this.compact,
    required this.selected,
    required this.plannedLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF201F27),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? FitColors.green.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Container(
                      width: double.infinity,
                      color: const Color(0xFF25212A),
                      child: _ExerciseGif(exercise: exercise),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected
                            ? FitColors.green
                            : Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        selected ? 'ADDED' : 'ADD',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14, compact ? 12 : 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_capitalize(exercise.target)} • ${_capitalize(exercise.equipmentLabel)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: FitColors.label, fontSize: compact ? 12 : 13),
                  ),
                  if (plannedLabel != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      plannedLabel!,
                      style: const TextStyle(
                          color: FitColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseGif extends StatelessWidget {
  final _ExerciseItem exercise;
  final BoxFit fit;

  const _ExerciseGif({required this.exercise, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    if (exercise.id.isEmpty || AppConstants.exerciseDbKey.isEmpty) {
      return _ExerciseFallbackIllustration(exercise: exercise);
    }

    return Image.network(
      '${AppConstants.exerciseDbBaseUrl}/image?exerciseId=${Uri.encodeComponent(exercise.id)}&resolution=360',
      headers: const {
        'x-rapidapi-host': AppConstants.exerciseDbHost,
        'x-rapidapi-key': AppConstants.exerciseDbKey,
      },
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          _ExerciseFallbackIllustration(exercise: exercise),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child:
              CircularProgressIndicator(color: FitColors.green, strokeWidth: 2),
        );
      },
    );
  }
}

class _ExerciseFallbackIllustration extends StatelessWidget {
  final _ExerciseItem exercise;

  const _ExerciseFallbackIllustration({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B313E), Color(0xFF1B1F28)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fitness_center_rounded,
          size: 86,
          color: _bodyPartColor(exercise.bodyPart).withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;

  const _InfoPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2236),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: FitColors.label, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PoseAssistToggle extends StatelessWidget {
  final bool isSupported;
  final bool isActive;
  final ValueChanged<bool> onToggle;

  const _PoseAssistToggle({
    required this.isSupported,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final title = isSupported
        ? 'Pose detection assistance'
        : 'Pose detection unavailable';
    final subtitle = isSupported
        ? 'Use your camera to monitor form, count reps, and get immediate feedback.'
        : 'Available when you use an Android or iOS device with camera access.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2236),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
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
          Switch.adaptive(
            value: isActive,
            onChanged: isSupported ? onToggle : null,
            activeColor: FitColors.green,
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  const _NumberField({
    required this.controller,
    required this.label,
    this.enabled = true,
    this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFF1B2236),
        labelStyle: const TextStyle(color: FitColors.label),
        hintStyle: const TextStyle(color: FitColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
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

class _WorkoutSessionScreen extends StatefulWidget {
  final DateTime startedAt;
  final List<_PlannedExercise> plannedExercises;

  const _WorkoutSessionScreen({
    required this.startedAt,
    required this.plannedExercises,
  });

  @override
  State<_WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<_WorkoutSessionScreen> {
  late List<_PlannedExercise> _sessionExercises;
  late Timer _timer;
  Duration _elapsed = Duration.zero;
  int _currentIndex = 0;
  bool _poseAssistActive = false;

  @override
  void initState() {
    super.initState();
    _sessionExercises =
        widget.plannedExercises.map((item) => item.copyWith()).toList();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(widget.startedAt);
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  _PlannedExercise get _currentExercise => _sessionExercises[_currentIndex];

  double get _completedCalories =>
      _sessionExercises.fold(0, (sum, item) => sum + item.actualCalories);

  int get _completedSets =>
      _sessionExercises.fold(0, (sum, item) => sum + item.completedSets);

  bool get _isPoseSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _togglePoseAssist(bool value) async {
    if (!_isPoseSupported) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Pose detection is available on Android and iOS devices only.',
        ),
      ));
      return;
    }

    if (!value) {
      setState(() => _poseAssistActive = false);
      return;
    }

    if (_poseAssistActive) return;

    setState(() => _poseAssistActive = true);

    final exercise = _currentExercise.exercise;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExercisePoseMonitorScreen(
          exerciseName: exercise.displayName,
          bodyPart: exercise.bodyPart,
          target: exercise.target,
        ),
      ),
    );

    if (!mounted) return;

    setState(() => _poseAssistActive = false);
  }

  Future<void> _finishWorkout() async {
    final completed =
        _sessionExercises.where((item) => item.completedSets > 0).toList();
    if (completed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Complete at least one set before finishing the workout.')),
      );
      return;
    }

    Navigator.of(context).pop(
      _CompletedWorkoutResult(
        startedAt: widget.startedAt,
        endedAt: DateTime.now(),
        completedExercises: completed,
      ),
    );
  }

  void _completeSet() {
    final current = _currentExercise;
    if (current.completedSets >= current.sets) {
      return;
    }

    setState(() {
      _sessionExercises[_currentIndex] =
          current.copyWith(completedSets: current.completedSets + 1);
      if (_sessionExercises[_currentIndex].isComplete &&
          _currentIndex < _sessionExercises.length - 1) {
        _currentIndex += 1;
      }
    });
  }

  void _goToNextExercise() {
    if (_currentIndex >= _sessionExercises.length - 1) return;
    setState(() => _currentIndex += 1);
  }

  Future<void> _confirmExit() async {
    final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF161E32),
            title: const Text('Leave workout?',
                style: TextStyle(color: Colors.white)),
            content: const Text(
              'If you leave now, the workout will not be saved to the backend.',
              style: TextStyle(color: FitColors.label),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Stay')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Leave')),
            ],
          ),
        ) ??
        false;

    if (shouldLeave && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentExercise;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmExit();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TopActionButton(
                        icon: Icons.close_rounded, onTap: _confirmExit),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Workout In Progress',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171F33),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _formatDuration(_elapsed),
                        style: const TextStyle(
                            color: FitColors.green,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171F33),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: _MiniStat(
                              label: 'Exercise',
                              value:
                                  '${_currentIndex + 1}/${_sessionExercises.length}')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _MiniStat(
                              label: 'Sets Done', value: '$_completedSets')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _MiniStat(
                              label: 'Calories',
                              value: _completedCalories.toStringAsFixed(0))),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF171F33),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(26)),
                            child: Container(
                              width: double.infinity,
                              color: const Color(0xFF25212A),
                              child: _ExerciseGif(
                                  exercise: current.exercise,
                                  fit: BoxFit.contain),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current.exercise.displayName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoPill(
                                      text: _capitalize(
                                          current.exercise.bodyPart)),
                                  _InfoPill(text: '${current.reps} reps'),
                                  _InfoPill(
                                      text: '${current.setsLeft} sets left'),
                                  _InfoPill(
                                      text:
                                          '${current.weightKg.toStringAsFixed(current.weightKg == current.weightKg.roundToDouble() ? 0 : 1)} kg'),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                current.exercise.instructions.isEmpty
                                    ? 'Follow the ExerciseDB movement pattern shown above.'
                                    : current.exercise.instructions.first,
                                style: const TextStyle(
                                    color: FitColors.label,
                                    fontSize: 14,
                                    height: 1.45),
                              ),
                              const SizedBox(height: 18),
                              _PoseAssistToggle(
                                isSupported: _isPoseSupported,
                                isActive: _poseAssistActive,
                                onToggle: _togglePoseAssist,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _currentIndex < _sessionExercises.length - 1
                            ? _goToNextExercise
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2)),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('NEXT EXERCISE'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: current.isComplete &&
                                _currentIndex == _sessionExercises.length - 1
                            ? _finishWorkout
                            : _completeSet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FitColors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          current.isComplete &&
                                  _currentIndex == _sessionExercises.length - 1
                              ? 'FINISH WORKOUT'
                              : 'COMPLETE SET',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletedWorkoutResult {
  final DateTime startedAt;
  final DateTime endedAt;
  final List<_PlannedExercise> completedExercises;

  const _CompletedWorkoutResult({
    required this.startedAt,
    required this.endedAt,
    required this.completedExercises,
  });

  Duration get duration => endedAt.difference(startedAt);

  double get totalCalories =>
      completedExercises.fold(0, (sum, item) => sum + item.actualCalories);
}

IconData _equipmentFilterIcon(ExerciseEquipmentFilter filter) {
  switch (filter) {
    case ExerciseEquipmentFilter.all:
      return Icons.apps_rounded;
    case ExerciseEquipmentFilter.withEquipment:
      return Icons.fitness_center_rounded;
    case ExerciseEquipmentFilter.withoutEquipment:
      return Icons.accessibility_new_rounded;
  }
}

String _equipmentFilterLabel(ExerciseEquipmentFilter filter) {
  switch (filter) {
    case ExerciseEquipmentFilter.all:
      return 'All';
    case ExerciseEquipmentFilter.withEquipment:
      return 'Equipment';
    case ExerciseEquipmentFilter.withoutEquipment:
      return 'Bodyweight';
  }
}

Color _bodyPartColor(String bodyPart) {
  switch (bodyPart) {
    case 'chest':
      return const Color(0xFFFF6B6B);
    case 'shoulders':
      return const Color(0xFFFF944D);
    case 'arms':
    case 'upper arms':
      return const Color(0xFFFF7A59);
    case 'back':
      return const Color(0xFFFF5A5F);
    case 'legs':
    case 'upper legs':
      return const Color(0xFF2ED06E);
    default:
      return FitColors.green;
  }
}

String _capitalize(String text) {
  if (text.isEmpty) return text;
  final value = text.replaceAll('-', ' ');
  return value[0].toUpperCase() + value.substring(1);
}

String _titleCase(String text) {
  return text
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => _capitalize(part.toLowerCase()))
      .join(' ');
}

String _formatDateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatTimeOnly(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
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

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }
}
