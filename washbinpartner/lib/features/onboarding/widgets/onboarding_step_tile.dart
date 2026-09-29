import 'package:flutter/material.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';

/// One task on the onboarding checklist.
///
/// Shows what is outstanding rather than only that something is — "Still
/// needed: Email address" saves a partner opening the form to find out.
class OnboardingStepTile extends StatelessWidget {
  const OnboardingStepTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.onTap,
    this.progressLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDone;
  final VoidCallback onTap;

  /// A short "2/3" or "4" shown alongside the tick.
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    const done = Color(0xFF1B8A4B);
    final accent = isDone ? done : AppTheme.red;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : icon,
                  color: accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (progressLabel != null) ...[
                const SizedBox(width: 10),
                Text(
                  progressLabel!,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
