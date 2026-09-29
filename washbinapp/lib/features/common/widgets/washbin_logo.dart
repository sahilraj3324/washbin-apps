import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';

class WashbinLogo extends StatelessWidget {
  const WashbinLogo({super.key, required this.size, this.showShadow = true});

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppTheme.darkRed.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.64,
            height: size * 0.64,
            decoration: BoxDecoration(
              color: AppTheme.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
          ),
          Icon(
            Icons.cleaning_services_rounded,
            size: size * 0.54,
            color: AppTheme.red,
          ),
          Positioned(
            right: size * 0.15,
            top: size * 0.16,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB13B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.home_rounded,
                size: size * 0.15,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
