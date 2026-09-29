import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';

/// A titled band on a browse screen, optionally with an action on the right.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
