import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';

/// The app's one spinner. Sized for inline use by default; pass a [label] when
/// the wait is long enough that the customer deserves to know what for.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.label, this.size = 22});

  /// Fills the available space and centres itself — for a screen body that has
  /// nothing to show yet.
  const AppLoadingIndicator.fullScreen({super.key, this.label}) : size = 30;

  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(
        strokeWidth: 2.4,
        color: AppTheme.red,
      ),
    );

    if (label == null) {
      return Center(child: indicator);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(height: 14),
          Text(
            label!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
