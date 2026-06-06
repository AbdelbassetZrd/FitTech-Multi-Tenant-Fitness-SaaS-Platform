import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = BrandMark(compact: compact);

    if (compact) {
      return icon;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: 12),
        const Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'FITTECH PRO',
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Coach Operations Console',
                  maxLines: 1,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 42.0 : 52.0;
    final strokeColor = AppColors.green;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: strokeColor, width: 2),
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.52,
          height: size * 0.52,
          child: Stack(
            alignment: Alignment.center,
            children: const [
              BrandCrossBar(angle: -0.78),
              BrandCrossBar(angle: 0.78),
            ],
          ),
        ),
      ),
    );
  }
}

class BrandCrossBar extends StatelessWidget {
  const BrandCrossBar({required this.angle});

  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: SizedBox(
        width: 20,
        height: 20,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 16,
              height: 2.4,
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Positioned(
              left: 1,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 1,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
