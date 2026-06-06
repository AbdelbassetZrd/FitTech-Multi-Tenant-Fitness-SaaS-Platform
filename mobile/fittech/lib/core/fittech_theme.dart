import 'package:flutter/material.dart';

// ─── Brand Colors ─────────────────────────────────────────────────────────────
class FitColors {
  FitColors._();
  static const Color green      = Color(0xFF22C55E);
  static const Color bgTop      = Color(0xFF3D1A1A);
  static const Color bgBottom   = Color(0xFF1A1A2E);
  static const Color surface    = Color(0xFF1E2235);
  static const Color hint       = Color(0xFF555870);
  static const Color label      = Color(0xFFB0B0C0);
  static const Color muted      = Color(0xFF888899);
}

// ─── Gradient Background ──────────────────────────────────────────────────────
class FitBackground extends StatelessWidget {
  final Widget child;
  const FitBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [FitColors.bgTop, FitColors.bgBottom],
        ),
      ),
      child: child,
    );
  }
}

// ─── Logo ─────────────────────────────────────────────────────────────────────
class FitLogo extends StatelessWidget {
  final double size;
  const FitLogo({super.key, this.size = 90});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: FitColors.green, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: FitColors.green.withOpacity(0.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child:
            Icon(Icons.fitness_center, color: FitColors.green, size: size * 0.44),
      ),
    );
  }
}

// ─── Premium Badge ────────────────────────────────────────────────────────────
class FitBadge extends StatelessWidget {
  const FitBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: FitColors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FitColors.green.withOpacity(0.5)),
      ),
      child: const Text(
        'FITTECH PREMIUM',
        style: TextStyle(
          color: FitColors.green,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

// ─── Field Label ─────────────────────────────────────────────────────────────
class FitLabel extends StatelessWidget {
  final String text;
  const FitLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: FitColors.label,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
      );
}

// ─── Text Input Field ─────────────────────────────────────────────────────────
class FitInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final bool enabled;

  const FitInputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FitColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        enabled: enabled,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: FitColors.hint,
            fontSize: obscure ? 20 : 14,
            letterSpacing: obscure ? 4 : 0,
          ),
          prefixIcon: Icon(prefixIcon, color: FitColors.hint, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ─── Primary Button ───────────────────────────────────────────────────────────
class FitPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const FitPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: FitColors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: FitColors.green.withOpacity(0.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }
}

// ─── Outlined Back Button ─────────────────────────────────────────────────────
class FitBackButton extends StatelessWidget {
  const FitBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: FitColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ─── Google Logo (CustomPainter) ──────────────────────────────────────────────
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(22, 22), painter: _GoogleLogoPainter());
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    final segments = <List<dynamic>>[
      [const Color(0xFF4285F4), -90.0, 90.0],
      [const Color(0xFFEA4335), 0.0, 90.0],
      [const Color(0xFFFBBC05), 90.0, 90.0],
      [const Color(0xFF34A853), 180.0, 90.0],
    ];

    for (final s in segments) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        (s[1] as double) * 3.14159265 / 180,
        (s[2] as double) * 3.14159265 / 180,
        true,
        Paint()..color = s[0] as Color,
      );
    }

    canvas.drawCircle(Offset(cx, cy), r * 0.58, Paint()..color = Colors.white);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.18, r, r * 0.36),
      Paint()..color = const Color(0xFF4285F4),
    );
    canvas.drawCircle(Offset(cx, cy), r * 0.58, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
