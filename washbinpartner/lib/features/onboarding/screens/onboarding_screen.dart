import 'package:flutter/material.dart';
import 'package:washbinpartner/app/app_services_scope.dart';
import 'package:washbinpartner/app/router/app_router.dart';
import 'package:washbinpartner/core/api/api_exception.dart';
import 'package:washbinpartner/core/async/async_controller.dart';
import 'package:washbinpartner/core/async/async_state.dart';
import 'package:washbinpartner/core/session/session_scope.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/features/common/widgets/washbin_logo.dart';
import 'package:washbinpartner/features/partner/domain/partner.dart';
import 'package:washbinpartner/features/partner/domain/profile_completeness.dart';
import 'package:washbinpartner/features/onboarding/widgets/onboarding_status_card.dart';
import 'package:washbinpartner/features/onboarding/widgets/onboarding_step_tile.dart';

/// Home for a partner who cannot take work yet.
///
/// Covers three stages with one screen, because they are the same two tasks
/// seen from different points: fill in the profile, choose the services, ask
/// for a review. What changes between them is the status at the top and
/// whether the submit button is there at all.
///
/// A suspended partner never reaches this screen — there is nothing here they
/// could usefully do. `AppGate` sends them to `PartnerStatusScreen` instead.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// How many services the partner currently offers. Its own read because the
  /// session holds the partner, not their service list.
  late final AsyncController<int> _serviceCount = AsyncController(_readCount);

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    // The session rebuilds this screen when the partner changes, but nothing
    // watches the service count — so it is subscribed to explicitly.
    _serviceCount.addListener(_onServiceCountChanged);
    _serviceCount.load();
  }

  @override
  void dispose() {
    _serviceCount
      ..removeListener(_onServiceCountChanged)
      ..dispose();
    super.dispose();
  }

  void _onServiceCountChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<int> _readCount() async {
    final rows = await AppServicesScope.of(context).partnerServices.getMine();
    return rows.where((row) => row.isActive).length;
  }

  Future<void> _refresh() async {
    final messenger = ScaffoldMessenger.of(context);
    final session = SessionScope.read(context);

    // Both, because either can have moved: Washbin may have reviewed the
    // partner, and the service list may have been changed on another device.
    await _serviceCount.refresh();
    try {
      await session.refreshPartner();
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openProfile(Partner partner) async {
    await Navigator.of(context).push(AppRouter.profileEdit(partner));
    // The session already has the saved partner; nothing else to re-read.
  }

  Future<void> _openServices() async {
    await Navigator.of(
      context,
    ).push(AppRouter.myServices(onChanged: _serviceCount.refresh));
    await _serviceCount.refresh();
  }

  /// Asks Washbin for a review.
  ///
  /// The server checks the same two conditions and refuses with its own
  /// message, so a failure here means the app's copy of the rule has drifted —
  /// which is why the message is shown rather than swallowed.
  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final partners = AppServicesScope.of(context).partners;
    final session = SessionScope.read(context);

    try {
      final result = await partners.submitForReview();
      // Moves the stage to pendingApproval, which rebuilds this screen into
      // its waiting form.
      session.applyPartner(result.partner);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _submitError = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final partner = session.partner;

    if (partner == null) {
      return const SizedBox.shrink();
    }

    final completeness = ProfileCompleteness.of(partner);
    final countState = _serviceCount.state;
    final count = countState.valueOrNull;
    final hasServices = (count ?? 0) > 0;
    final canSubmit =
        completeness.isComplete &&
        hasServices &&
        partner.stage != PartnerStage.pendingApproval;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.red,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(
                children: [
                  const WashbinLogo(size: 40, showShadow: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      partner.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              OnboardingStatusCard(partner: partner),
              const SizedBox(height: 24),
              const Text(
                'Before you can go online',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              OnboardingStepTile(
                icon: Icons.badge_outlined,
                title: 'Profile details',
                subtitle: completeness.isComplete
                    ? 'All set'
                    : 'Still needed: '
                          '${completeness.missing.map((m) => m.label).join(', ')}',
                isDone: completeness.isComplete,
                progressLabel:
                    '${completeness.satisfiedCount}/${completeness.totalCount}',
                onTap: () => _openProfile(partner),
              ),
              const SizedBox(height: 10),
              OnboardingStepTile(
                icon: Icons.home_repair_service_outlined,
                title: 'My services',
                subtitle: switch (countState) {
                  AsyncLoading<int>() => 'Checking...',
                  AsyncFailure<int>(:final error) => error.message,
                  _ when hasServices =>
                    'You offer $count ${count == 1 ? 'service' : 'services'}',
                  _ => 'Choose the work you take on',
                },
                isDone: hasServices,
                progressLabel: count == null ? null : '$count',
                onTap: _openServices,
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 16),
                _SubmitError(message: _submitError!),
              ],
              const SizedBox(height: 24),
              if (partner.stage == PartnerStage.pendingApproval)
                _UnderReviewNote(submittedAt: partner.submittedAt)
              else
                FilledButton.icon(
                  onPressed: canSubmit && !_isSubmitting ? _submit : null,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting
                        ? 'Submitting...'
                        : partner.stage == PartnerStage.rejected
                        ? 'Submit again'
                        : 'Submit for review',
                  ),
                ),
              if (!canSubmit && partner.stage != PartnerStage.pendingApproval)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Finish both steps above to send your profile to Washbin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: session.signOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnderReviewNote extends StatelessWidget {
  const _UnderReviewNote({required this.submittedAt});

  final DateTime? submittedAt;

  @override
  Widget build(BuildContext context) {
    final when = submittedAt?.toLocal();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: AppTheme.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              when == null
                  ? 'Sent to Washbin. Pull down to check for an update.'
                  : 'Sent on ${when.day}/${when.month}/${when.year}. Pull down '
                        'to check for an update.',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitError extends StatelessWidget {
  const _SubmitError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkRed.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.darkRed,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.darkRed,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
