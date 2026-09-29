import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';

/// One labelled line in the booking summary.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.icon,
    this.emphasise = false,
    this.onEdit,
  });

  final String label;
  final String value;
  final String? detail;
  final IconData? icon;

  /// Prints the value large and in the brand colour — for the price.
  final bool emphasise;

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppTheme.muted),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: emphasise ? AppTheme.red : AppTheme.ink,
                    fontSize: emphasise ? 22 : 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.25,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onEdit != null)
            TextButton(onPressed: onEdit, child: const Text('Change')),
        ],
      ),
    );
  }
}
