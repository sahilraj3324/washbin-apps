import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/common/widgets/washbin_logo.dart';

/// The shared navy-hero frame every step of the OTP flow sits in, so moving
/// from number to code to name reads as one screen changing its copy.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    this.showSkip = false,
    this.onSkip,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;
  final bool showSkip;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 520 : double.infinity,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: isWide ? 340 : 360,
                      child: _AuthHero(
                        title: title,
                        subtitle: subtitle,
                        onBack: onBack,
                        showSkip: showSkip,
                        onSkip: onSkip,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(34),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            isWide ? 36 : 36,
                            34,
                            isWide ? 36 : 22,
                            32,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.showSkip,
    required this.onSkip,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final bool showSkip;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.deepNavy,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _LaundryHeroPainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 22, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onBack != null) ...[
                      _HeroIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: onBack!,
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              const WashbinLogo(size: 44, showShadow: false),
                              const SizedBox(width: 12),
                              const Text(
                                'WashBin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                              Text(
                                '.',
                                style: TextStyle(
                                  color: AppTheme.washbinYellow,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (showSkip)
                      TextButton.icon(
                        onPressed: onSkip,
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Skip login'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      height: 1.16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.washbinYellow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 260,
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LaundryHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final accent = Paint()
      ..color = AppTheme.washbinYellow.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    final blue = Paint()
      ..color = AppTheme.royalBlue.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final right = size.width - 34;
    final baseY = size.height - 50;
    final machineRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(right - 118, baseY - 96, 76, 92),
      const Radius.circular(8),
    );

    canvas.drawCircle(Offset(size.width * 0.46, baseY - 6), 94, line);
    canvas.drawRRect(machineRect, line);
    canvas.drawCircle(Offset(right - 80, baseY - 46), 22, line);
    canvas.drawCircle(Offset(right - 80, baseY - 46), 12, line);
    canvas.drawLine(
      Offset(right - 118, baseY - 70),
      Offset(right - 42, baseY - 70),
      line,
    );
    canvas.drawCircle(Offset(right - 96, baseY - 82), 4, accent);
    canvas.drawCircle(Offset(right - 80, baseY - 82), 4, blue);
    canvas.drawCircle(Offset(right - 64, baseY - 82), 4, accent);

    final basketPath = Path()
      ..moveTo(right - 36, baseY - 56)
      ..lineTo(right - 12, baseY - 56)
      ..lineTo(right - 18, baseY - 4)
      ..lineTo(right - 30, baseY - 4)
      ..close();
    canvas.drawPath(basketPath, line);
    canvas.drawLine(
      Offset(right - 33, baseY - 45),
      Offset(right - 15, baseY - 45),
      line,
    );
    canvas.drawLine(
      Offset(right - 31, baseY - 31),
      Offset(right - 17, baseY - 31),
      line,
    );

    canvas.drawCircle(Offset(right - 28, baseY - 76), 11, accent);
    canvas.drawCircle(Offset(right - 8, baseY - 76), 8, blue);
    canvas.drawCircle(Offset(right - 18, baseY - 93), 6, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
