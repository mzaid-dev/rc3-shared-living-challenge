import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Hisab Split-Donut Brand Emblem
/// Renders the three-way household split ring on a Jade 600 squircle
class HisabLogoMark extends StatelessWidget {
  final double size;
  final double borderRadius;

  const HisabLogoMark({
    super.key,
    this.size = 32,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.jade600,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: CustomPaint(
        painter: _SplitDonutPainter(),
      ),
    );
  }
}

class _SplitDonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.31;
    final strokeWidth = size.width * 0.12;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Segment 1 (Ali's 38% share)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 0.72,
      false,
      paint,
    );

    // Segment 2 (Ayesha's 31% share)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.36,
      math.pi * 0.55,
      false,
      paint,
    );

    // Segment 3 (Bilal's 31% share)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 1.05,
      math.pi * 0.55,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Hisab Brand Title with Jade accent dot
class HisabBrandWordmark extends StatelessWidget {
  final double fontSize;

  const HisabBrandWordmark({
    super.key,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: AppColors.jade800,
        ),
        children: const [
          TextSpan(text: 'Hisab'),
          TextSpan(
            text: '.',
            style: TextStyle(color: AppColors.jade500),
          ),
        ],
      ),
    );
  }
}
