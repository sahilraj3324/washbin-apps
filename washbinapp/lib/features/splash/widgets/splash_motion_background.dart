import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';

class SplashMotionBackground extends StatelessWidget {
  const SplashMotionBackground({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SplashMotionPainter(progress),
      child: const SizedBox.expand(),
    );
  }
}

class _SplashMotionPainter extends CustomPainter {
  const _SplashMotionPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = math.min(size.width, size.height);
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 5; i++) {
      final cycle = (progress + i * 0.16) % 1;
      final radius = shortest * (0.15 + cycle * 0.58);
      wavePaint
        ..strokeWidth = 12 * (1 - cycle)
        ..color = Colors.white.withValues(alpha: 0.18 * (1 - cycle));
      canvas.drawCircle(center, radius, wavePaint);
    }

    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.16);

    for (var i = 0; i < 3; i++) {
      final rect = Rect.fromCenter(
        center: center,
        width: shortest * (0.6 + i * 0.22),
        height: shortest * (0.36 + i * 0.16),
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((progress * math.pi * 2) + i * 0.55);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawOval(rect, pathPaint);
      canvas.restore();
    }

    final tagPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 8; i++) {
      final angle = (progress * math.pi * 2) + (i * math.pi / 4);
      final orbit = shortest * (0.28 + (i % 2) * 0.12);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * orbit;
      final isAccent = i % 3 == 0;
      tagPaint.color = isAccent
          ? const Color(0xFFFFB13B).withValues(alpha: 0.42)
          : Colors.white.withValues(alpha: 0.2);
      _drawTag(canvas, point, angle, tagPaint, isAccent ? 26 : 18);
    }

    final bottomPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppTheme.darkRed.withValues(alpha: 0.22);
    final bottomPath = Path()
      ..moveTo(0, size.height * 0.78)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.72,
        size.width * 0.7,
        size.height * 0.9,
        size.width,
        size.height * 0.82,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(bottomPath, bottomPaint);
  }

  void _drawTag(
    Canvas canvas,
    Offset center,
    double angle,
    Paint paint,
    double side,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: side * 1.32, height: side),
      const Radius.circular(6),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle + math.pi / 7);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplashMotionPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
