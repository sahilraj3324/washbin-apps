import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/addresses/domain/address.dart';
import 'package:washbinapp/features/addresses/widgets/address_card.dart';

/// Home / Work / Other, as three buttons rather than a dropdown — there are
/// only ever three, and they are the first thing the form asks.
class LabelSelector extends StatelessWidget {
  const LabelSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final AddressLabel value;
  final ValueChanged<AddressLabel> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final label in AddressLabel.values) ...[
          Expanded(
            child: _LabelChip(
              label: label,
              isSelected: label == value,
              onTap: enabled ? () => onChanged(label) : null,
            ),
          ),
          if (label != AddressLabel.values.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final AddressLabel label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppTheme.red.withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.red : AppTheme.line,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                iconForLabel(label),
                size: 20,
                color: isSelected ? AppTheme.red : AppTheme.muted,
              ),
              const SizedBox(height: 6),
              Text(
                label.display,
                style: TextStyle(
                  color: isSelected ? AppTheme.red : AppTheme.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
