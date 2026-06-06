import 'package:flutter/material.dart';
import 'today_workout_screen.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TodayWorkoutScreen();
  }
}

/*
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: FitColors.label,
                                          fontSize: 15,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final compact =
                                          constraints.maxWidth < 390;
                                      return GridView.builder(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          6,
                                          12,
                                          24,
                                        ),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: compact ? 10 : 14,
                                          crossAxisSpacing: compact ? 10 : 14,
                                          childAspectRatio:
                                              compact ? 0.64 : 0.68,
                                        ),
                                        itemCount: filteredExercises.length,
                                        itemBuilder: (context, index) {
                                          return _ExerciseCard(
                                            exercise: filteredExercises[index],
                                            compact: compact,
                                            onTap: () => _showExerciseDetails(
                                              filteredExercises[index],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ],
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

enum ExerciseEquipmentFilter { all, withEquipment, withoutEquipment }

class _BodyPartFilter {
  final String label;
  final String apiValue;
  final String highlight;

  const _BodyPartFilter({
    required this.label,
    required this.apiValue,
    required this.highlight,
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

  String get displayName => _titleCase(name);
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

class _BodyPartCard extends StatelessWidget {
  final _BodyPartFilter item;
  final bool selected;
  final VoidCallback onTap;

  const _BodyPartCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E2433) : const Color(0xFF121826),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _BodyPartMiniIllustration(bodyPart: item.highlight),
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
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

class _BodyPartMiniIllustration extends StatelessWidget {
  final String bodyPart;

  const _BodyPartMiniIllustration({required this.bodyPart});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.78,
      child: CustomPaint(
        painter: _BodyPartThumbnailPainter(bodyPart: bodyPart),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BodyPartThumbnailPainter extends CustomPainter {
  final String bodyPart;

  const _BodyPartThumbnailPainter({required this.bodyPart});

  bool get _isBackView => bodyPart == 'back';

  @override
  void paint(Canvas canvas, Size size) {
    final silhouettePaint = Paint()..color = const Color(0xFFE8E8EA);
    final outlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final accentPaint = Paint()..color = _bodyPartColor(bodyPart);
    final secondaryAccentPaint = Paint()
      ..color = _bodyPartColor(bodyPart).withValues(alpha: 0.72);

    final centerX = size.width / 2;
    final headRadius = size.width * 0.12;
    final shoulderY = size.height * 0.24;
    final hipY = size.height * 0.55;
    final kneeY = size.height * 0.77;
    final footY = size.height * 0.95;

    canvas.drawCircle(
      Offset(centerX, size.height * 0.12),
      headRadius,
      silhouettePaint,
    );
    canvas.drawCircle(
      Offset(centerX, size.height * 0.12),
      headRadius,
      outlinePaint,
    );

    final torso = Path()
      ..moveTo(centerX - size.width * 0.17, shoulderY)
      ..quadraticBezierTo(
        centerX - size.width * 0.2,
        size.height * 0.38,
        centerX - size.width * 0.12,
        hipY,
      )
      ..lineTo(centerX + size.width * 0.12, hipY)
      ..quadraticBezierTo(
        centerX + size.width * 0.2,
        size.height * 0.38,
        centerX + size.width * 0.17,
        shoulderY,
      )
      ..close();
    canvas.drawPath(torso, silhouettePaint);
    canvas.drawPath(torso, outlinePaint);

    final leftArm = RRect.fromLTRBR(
      centerX - size.width * 0.32,
      shoulderY,
      centerX - size.width * 0.2,
      size.height * 0.62,
      Radius.circular(size.width * 0.08),
    );
    final rightArm = RRect.fromLTRBR(
      centerX + size.width * 0.2,
      shoulderY,
      centerX + size.width * 0.32,
      size.height * 0.62,
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(leftArm, silhouettePaint);
    canvas.drawRRect(rightArm, silhouettePaint);
    canvas.drawRRect(leftArm, outlinePaint);
    canvas.drawRRect(rightArm, outlinePaint);

    final leftLeg = Path()
      ..moveTo(centerX - size.width * 0.1, hipY)
      ..lineTo(centerX - size.width * 0.21, footY)
      ..lineTo(centerX - size.width * 0.08, footY)
      ..lineTo(centerX - size.width * 0.01, kneeY)
      ..close();
    final rightLeg = Path()
      ..moveTo(centerX + size.width * 0.1, hipY)
      ..lineTo(centerX + size.width * 0.21, footY)
      ..lineTo(centerX + size.width * 0.08, footY)
      ..lineTo(centerX + size.width * 0.01, kneeY)
      ..close();
    canvas.drawPath(leftLeg, silhouettePaint);
    canvas.drawPath(rightLeg, silhouettePaint);
    canvas.drawPath(leftLeg, outlinePaint);
    canvas.drawPath(rightLeg, outlinePaint);

    _paintHighlights(canvas, size, accentPaint, secondaryAccentPaint);
  }

  void _paintHighlights(
    Canvas canvas,
    Size size,
    Paint accentPaint,
    Paint secondaryAccentPaint,
  ) {
    final centerX = size.width / 2;

    switch (bodyPart) {
      case 'chest':
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(centerX - size.width * 0.1, size.height * 0.34),
            width: size.width * 0.16,
            height: size.height * 0.12,
          ),
          accentPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(centerX + size.width * 0.1, size.height * 0.34),
            width: size.width * 0.16,
            height: size.height * 0.12,
          ),
          accentPaint,
        );
        break;
      case 'shoulders':
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(centerX - size.width * 0.22, size.height * 0.26),
            width: size.width * 0.13,
            height: size.height * 0.11,
          ),
          accentPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(centerX + size.width * 0.22, size.height * 0.26),
            width: size.width * 0.13,
            height: size.height * 0.11,
          ),
          accentPaint,
        );
        break;
      case 'arms':
        canvas.drawRRect(
          RRect.fromLTRBR(
            centerX - size.width * 0.31,
            size.height * 0.3,
            centerX - size.width * 0.2,
            size.height * 0.57,
            Radius.circular(size.width * 0.05),
          ),
          accentPaint,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(
            centerX + size.width * 0.2,
            size.height * 0.3,
            centerX + size.width * 0.31,
            size.height * 0.57,
            Radius.circular(size.width * 0.05),
          ),
          accentPaint,
        );
        break;
      case 'back':
        final upperBack = Path()
          ..moveTo(centerX - size.width * 0.15, size.height * 0.24)
          ..lineTo(centerX - size.width * 0.05, size.height * 0.53)
          ..lineTo(centerX - size.width * 0.16, size.height * 0.53)
          ..close();
        final upperBackRight = Path()
          ..moveTo(centerX + size.width * 0.15, size.height * 0.24)
          ..lineTo(centerX + size.width * 0.05, size.height * 0.53)
          ..lineTo(centerX + size.width * 0.16, size.height * 0.53)
          ..close();
        canvas.drawPath(upperBack, accentPaint);
        canvas.drawPath(upperBackRight, accentPaint);
        break;
      case 'legs':
        canvas.drawPath(
          Path()
            ..moveTo(centerX - size.width * 0.09, size.height * 0.56)
            ..lineTo(centerX - size.width * 0.19, size.height * 0.93)
            ..lineTo(centerX - size.width * 0.08, size.height * 0.93)
            ..lineTo(centerX - size.width * 0.01, size.height * 0.73)
            ..close(),
          accentPaint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(centerX + size.width * 0.09, size.height * 0.56)
            ..lineTo(centerX + size.width * 0.19, size.height * 0.93)
            ..lineTo(centerX + size.width * 0.08, size.height * 0.93)
            ..lineTo(centerX + size.width * 0.01, size.height * 0.73)
            ..close(),
          accentPaint,
        );
        break;
    }

    if (!_isBackView && bodyPart == 'chest') {
      canvas.drawRRect(
        RRect.fromLTRBR(
          centerX - size.width * 0.06,
          size.height * 0.31,
          centerX + size.width * 0.06,
          size.height * 0.5,
          Radius.circular(size.width * 0.04),
        ),
        secondaryAccentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BodyPartThumbnailPainter oldDelegate) {
    return oldDelegate.bodyPart != bodyPart;
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
            Icon(
              icon,
              size: 15,
              color: selected ? FitColors.green : FitColors.label,
            ),
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
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exercise,
    required this.compact,
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: const Color(0xFF25212A),
                      child: _ExerciseGif(exercise: exercise),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Icon(
                      Icons.bookmark_border_rounded,
                      color: Colors.white,
                      size: compact ? 22 : 24,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Icon(
                      Icons.help_outline_rounded,
                      color: Colors.white70,
                      size: compact ? 20 : 22,
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
                    _capitalize(exercise.bodyPart),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: FitColors.label,
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
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
      '${AppConstants.exerciseDbBaseUrl}/image?exerciseId=${Uri.encodeComponent(exercise.id)}&resolution=180',
      headers: const {
        'x-rapidapi-host': AppConstants.exerciseDbHost,
        'x-rapidapi-key': AppConstants.exerciseDbKey,
      },
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return _ExerciseFallbackIllustration(exercise: exercise);
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(
            color: FitColors.green,
            strokeWidth: 2,
          ),
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
    final highlightColor = _bodyPartColor(exercise.bodyPart);

    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2B313E), Color(0xFF1B1F28)],
              ),
            ),
          ),
        ),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.accessibility_new_rounded,
                size: 116,
                color: Colors.white.withValues(alpha: 0.88),
              ),
              ..._highlightShapes(
                exercise.bodyPart,
                const Size(116, 116),
                highlightColor,
              ),
            ],
          ),
        ),
      ],
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
          color: FitColors.label,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

List<Widget> _highlightShapes(String bodyPart, Size size, Color color) {
  final w = size.width;
  final h = size.height;

  switch (bodyPart) {
    case 'chest':
      return [
        _muscleDot(
            top: h * 0.28,
            left: w * 0.34,
            width: w * 0.16,
            height: h * 0.14,
            color: color),
        _muscleDot(
            top: h * 0.28,
            right: w * 0.34,
            width: w * 0.16,
            height: h * 0.14,
            color: color),
      ];
    case 'shoulders':
      return [
        _muscleDot(
            top: h * 0.2,
            left: w * 0.18,
            width: w * 0.13,
            height: h * 0.11,
            color: color),
        _muscleDot(
            top: h * 0.2,
            right: w * 0.18,
            width: w * 0.13,
            height: h * 0.11,
            color: color),
      ];
    case 'arms':
    case 'upper arms':
      return [
        _muscleDot(
            top: h * 0.35,
            left: w * 0.11,
            width: w * 0.1,
            height: h * 0.24,
            color: color),
        _muscleDot(
            top: h * 0.35,
            right: w * 0.11,
            width: w * 0.1,
            height: h * 0.24,
            color: color),
      ];
    case 'back':
      return [
        _muscleDot(
            top: h * 0.29,
            left: w * 0.38,
            width: w * 0.12,
            height: h * 0.29,
            color: color),
        _muscleDot(
            top: h * 0.29,
            right: w * 0.38,
            width: w * 0.12,
            height: h * 0.29,
            color: color),
      ];
    case 'legs':
    case 'upper legs':
      return [
        _muscleDot(
            top: h * 0.64,
            left: w * 0.39,
            width: w * 0.1,
            height: h * 0.22,
            color: color),
        _muscleDot(
            top: h * 0.64,
            right: w * 0.39,
            width: w * 0.1,
            height: h * 0.22,
            color: color),
      ];
    default:
      return const [];
  }
}

Widget _muscleDot({
  double? top,
  double? left,
  double? right,
  required double width,
  required double height,
  required Color color,
}) {
  return Positioned(
    top: top,
    left: left,
    right: right,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
    ),
  );
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

*/
