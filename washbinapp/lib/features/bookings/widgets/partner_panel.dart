import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/bookings/domain/partner_summary.dart';

/// Who is coming.
///
/// The API does not yet send partner details with a booking, so most of the
/// time this shows only that someone has been assigned. Every field is drawn
/// conditionally, which is what lets the panel fill itself in unchanged once
/// the booking response carries an `assignedPartner` object.
class PartnerPanel extends StatelessWidget {
  const PartnerPanel({
    super.key,
    required this.partner,
    required this.etaMinutes,
    this.onCall,
  });

  final PartnerSummary? partner;
  final int? etaMinutes;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final partner = this.partner;
    final eta = etaMinutes;

    return Container(
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
            'YOUR PARTNER',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.red.withValues(alpha: 0.12),
                backgroundImage: partner?.photoUrl == null
                    ? null
                    : NetworkImage(partner!.photoUrl!),
                child: partner?.photoUrl != null
                    ? null
                    : const Icon(
                        Icons.person_rounded,
                        color: AppTheme.red,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner?.name ?? 'Partner assigned',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (partner?.name == null)
                      const Text(
                        'Their details will appear here shortly.',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (partner!.hasRating)
                            _Chip(
                              icon: Icons.star_rounded,
                              text: partner.ratingLabel,
                            ),
                          if (partner.distanceLabel != null)
                            _Chip(
                              icon: Icons.near_me_rounded,
                              text: partner.distanceLabel!,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              if (onCall != null)
                IconButton.filledTonal(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_rounded),
                  color: AppTheme.red,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.red.withValues(alpha: 0.12),
                  ),
                ),
            ],
          ),
          if (eta != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppTheme.line),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 10),
                // Flexible so a larger accessibility text scale shortens the
                // label rather than overflowing the card.
                const Flexible(
                  child: Text(
                    'Estimated arrival',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Spacer(),
                Text(
                  eta == 1 ? '1 min' : '$eta mins',
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
