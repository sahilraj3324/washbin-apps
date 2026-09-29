import 'package:flutter/material.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';

/// A tab the shell has made room for but no phase has filled yet.
///
/// Deliberately says so rather than showing an empty list or zeroed figures: a
/// "0 jobs" tile is indistinguishable from a quiet day, and a partner would
/// reasonably believe it.
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
    this.upcoming = const [],
  });

  final String title;
  final IconData icon;
  final String message;

  /// What this tab will do once it is built.
  final List<String> upcoming;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: [
        Center(
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: AppTheme.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.red, size: 30),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.muted,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Coming here',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in upcoming) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.circle,
                          size: 7,
                          color: AppTheme.red,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item != upcoming.last) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
