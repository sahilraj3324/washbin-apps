import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/common/widgets/washbin_logo.dart';
import 'package:washbinapp/features/splash/widgets/splash_motion_background.dart';

/// The startup screen, and nothing more.
///
/// Deciding who is signed in used to happen here; it now belongs to
/// `SessionController`, which holds this screen up for a minimum duration and
/// then hands over to `AppGate`. This widget only animates.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _introController.dispose();
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_introController, _motionController]),
        builder: (context, child) {
          final intro = Curves.easeOutBack.transform(_introController.value);
          final softIntro = Curves.easeOutCubic.transform(
            _introController.value,
          );
          final float = math.sin(_motionController.value * math.pi * 2);

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFF4D5A), AppTheme.red, AppTheme.darkRed],
              ),
            ),
            child: Stack(
              children: [
                SplashMotionBackground(progress: _motionController.value),
                Center(
                  child: Transform.translate(
                    offset: Offset(0, 28 * (1 - softIntro) + float * 5),
                    child: Opacity(
                      opacity: softIntro,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.rotate(
                            angle: float * 0.04,
                            child: Transform.scale(
                              scale: intro.clamp(0.0, 1.0),
                              child: const WashbinLogo(size: 128),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Washbin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 46,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: const Text(
                              'Trusted help for every home.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 28,
                  right: 28,
                  bottom: 46,
                  child: _SplashProgress(value: _motionController.value),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SplashProgress extends StatelessWidget {
  const _SplashProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (index) {
        final isActive = value > index / 4;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            height: 5,
            margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }
}
