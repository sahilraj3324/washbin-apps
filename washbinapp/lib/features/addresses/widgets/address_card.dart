import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/addresses/domain/address.dart';

IconData iconForLabel(AddressLabel label) => switch (label) {
  AddressLabel.home => Icons.home_rounded,
  AddressLabel.work => Icons.work_rounded,
  AddressLabel.other => Icons.place_rounded,
};

/// One saved address. Used both in the address book and in the picker, so the
/// trailing widget is left to the caller — a menu in one, a tick in the other.
class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.address,
    this.onTap,
    this.trailing,
    this.isSelected = false,
    this.isBusy = false,
  });

  final Address address;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isSelected;

  /// Shows a spinner in place of [trailing] while this row is being checked.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  iconForLabel(address.label),
                  color: AppTheme.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          address.label.display,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: 8),
                          const _DefaultPill(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.streetLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.areaLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (address.landmark != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Near ${address.landmark}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.red,
                    ),
                  ),
                )
              else
                ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultPill extends StatelessWidget {
  const _DefaultPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Default',
        style: TextStyle(
          color: AppTheme.red,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
