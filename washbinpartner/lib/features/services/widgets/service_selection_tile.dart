import 'package:flutter/material.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/features/services/domain/service_selection.dart';

/// One service, and whether this partner offers it.
///
/// The whole tile is the target rather than a trailing checkbox: the tap does
/// the same thing wherever it lands, and a checkbox would suggest the change
/// is staged rather than saved on the spot.
class ServiceSelectionTile extends StatelessWidget {
  const ServiceSelectionTile({
    super.key,
    required this.selection,
    required this.onTap,
    this.isBusy = false,
  });

  final ServiceSelection selection;
  final VoidCallback onTap;

  /// A write for this row is in flight.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final service = selection.service;
    final isSelected = selection.isSelected;
    final duration = service.durationLabel;

    return Semantics(
      button: true,
      selected: isSelected,
      label: service.name,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: isBusy ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.red : AppTheme.line,
                width: isSelected ? 1.6 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Indicator(isSelected: isSelected, isBusy: isBusy),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Chip(text: service.priceLabel),
                          if (duration != null) ...[
                            const SizedBox(width: 8),
                            _Chip(text: duration),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.isSelected, required this.isBusy});

  final bool isSelected;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: Padding(
          padding: EdgeInsets.all(3),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.red,
          ),
        ),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.red : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? AppTheme.red : AppTheme.line,
          width: 1.6,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
