import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';

/// A count dot over an icon. Absent entirely at zero, rather than showing a
/// "0" the customer has to read to discover means nothing.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    super.key,
    required this.count,
    required this.child,
    this.background = Colors.white,
    this.foreground = AppTheme.red,
  });

  final int count;
  final Widget child;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              // Past a certain point the exact number stops being useful and
              // starts being a layout problem.
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
