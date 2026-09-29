import 'package:flutter/material.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/features/partner/domain/partner.dart';

/// Where this partner stands with Washbin, said plainly at the top of the
/// onboarding screen.
///
/// A rejection carries its reason. Showing "rejected" without one would leave
/// the partner guessing at what to change, which is the whole point of the
/// screen underneath.
class OnboardingStatusCard extends StatelessWidget {
  const OnboardingStatusCard({super.key, required this.partner});

  final Partner partner;

  @override
  Widget build(BuildContext context) {
    final (:title, :message, :icon, :isRefusal) = _copyFor(partner.stage);
    final accent = isRefusal ? AppTheme.darkRed : AppTheme.red;
    final reason = partner.rejectionReason;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          if (partner.stage == PartnerStage.rejected && reason != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkRed.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REASON',
                    style: TextStyle(
                      color: AppTheme.darkRed,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reason,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static ({String title, String message, IconData icon, bool isRefusal})
  _copyFor(PartnerStage stage) => switch (stage) {
    PartnerStage.profileIncomplete => (
      title: 'Finish setting up',
      message:
          'Complete your profile and choose the services you offer, then send '
          'them to Washbin for review.',
      icon: Icons.edit_note_rounded,
      isRefusal: false,
    ),
    PartnerStage.pendingApproval => (
      title: 'Pending approval',
      message:
          'Your profile has been submitted. We are reviewing your details, '
          'which usually takes 1-2 working days.',
      icon: Icons.hourglass_top_rounded,
      isRefusal: false,
    ),
    PartnerStage.rejected => (
      title: 'Profile rejected',
      message:
          'Washbin could not verify this business. Update what is below and '
          'send it again.',
      icon: Icons.report_gmailerrorred_rounded,
      isRefusal: true,
    ),
    PartnerStage.suspended => (
      title: 'Account suspended',
      message:
          'This partner account has been suspended. Contact Washbin support to '
          'find out what happens next.',
      icon: Icons.block_rounded,
      isRefusal: true,
    ),
    // The gate sends an approved partner to the app shell, so this is only
    // reachable in the instant between an approval landing and the rebuild.
    PartnerStage.approved => (
      title: 'Verified partner',
      message: 'You are cleared to take bookings.',
      icon: Icons.verified_rounded,
      isRefusal: false,
    ),
  };
}
