import 'package:flutter/material.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/theme/app_theme.dart';

/// A full-space failure state: what went wrong, and the way out.
///
/// Takes an [ApiException] rather than a string so the icon and the retry
/// button follow from the kind of failure instead of being chosen by hand at
/// every call site.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    this.icon = Icons.error_outline_rounded,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.secondaryAction,
  });

  AppErrorView.fromException(
    ApiException error, {
    super.key,
    VoidCallback? onRetry,
    this.retryLabel = 'Try again',
    this.secondaryAction,
  }) : message = error.message,
       icon = _iconFor(error.kind),
       onRetry = error.isRetryable ? onRetry : null;

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: AppTheme.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.red, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel),
              ),
            ],
            if (secondaryAction != null) ...[
              const SizedBox(height: 8),
              secondaryAction!,
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(ApiErrorKind kind) => switch (kind) {
    ApiErrorKind.network => Icons.wifi_off_rounded,
    ApiErrorKind.timeout => Icons.schedule_rounded,
    ApiErrorKind.server => Icons.cloud_off_rounded,
    ApiErrorKind.unauthorized || ApiErrorKind.forbidden => Icons.lock_rounded,
    ApiErrorKind.notFound => Icons.search_off_rounded,
    _ => Icons.error_outline_rounded,
  };
}
