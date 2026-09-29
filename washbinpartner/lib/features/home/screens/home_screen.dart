import 'package:flutter/material.dart';
import 'package:washbinpartner/app/app_services_scope.dart';
import 'package:washbinpartner/core/api/api_exception.dart';
import 'package:washbinpartner/core/session/session_scope.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/features/availability/data/partner_location_service.dart';
import 'package:washbinpartner/features/availability/domain/partner_availability.dart';
import 'package:washbinpartner/features/common/widgets/washbin_logo.dart';
import 'package:washbinpartner/features/jobs/domain/job_offer.dart';
import 'package:washbinpartner/features/jobs/domain/partner_dashboard.dart';
import 'package:washbinpartner/features/partner/domain/partner.dart';

/// The approved partner's availability console.
///
/// The switch is backed by `/availability/me` every time the screen opens, so
/// an app restart restores the backend state rather than trusting local memory.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenJobs, this.onOpenProfile});

  final VoidCallback? onOpenJobs;
  final VoidCallback? onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _defaultRadiusKm = 10.0;

  PartnerAvailability? _availability;
  PartnerDashboard? _dashboard;
  bool _isLoadingAvailability = true;
  bool _isLoadingDashboard = true;
  bool _isRefreshing = false;
  bool _isChangingAvailability = false;
  bool _isUpdatingRange = false;
  String? _dashboardError;
  double _radiusKm = _defaultRadiusKm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHome());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _availability?.isOnline == true) {
      _refreshOnlineLocation(showErrors: false);
    }
  }

  Future<void> _loadAvailability() async {
    final services = AppServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isLoadingAvailability = true);
    try {
      final availability = await services.availability.getMine();
      _applyAvailability(availability);
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isLoadingAvailability = false);
      }
    }
  }

  Future<void> _loadDashboard() async {
    final services = AppServicesScope.of(context);

    setState(() {
      _isLoadingDashboard = true;
      _dashboardError = null;
    });
    try {
      final dashboard = await services.jobExecution.getDashboard();
      if (!mounted) {
        return;
      }
      setState(() => _dashboard = dashboard);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _dashboardError = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDashboard = false);
      }
    }
  }

  Future<void> _loadHome() async {
    await Future.wait([_loadAvailability(), _loadDashboard()]);
  }

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }
    setState(() => _isRefreshing = true);

    final messenger = ScaffoldMessenger.of(context);
    try {
      await SessionScope.read(context).refreshPartner();
      if (_availability?.isOnline == true) {
        await _refreshOnlineLocation(showErrors: true);
      } else {
        await _loadAvailability();
      }
      await _loadDashboard();
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _goOnline(Partner partner) async {
    if (_isChangingAvailability) {
      return;
    }

    if (partner.stage != PartnerStage.approved ||
        partner.status != PartnerStatus.active) {
      _showMessage('Only approved active partners can go online.');
      return;
    }

    final services = AppServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isChangingAvailability = true);

    try {
      final rows = await services.partnerServices.getMine();
      if (rows.every((row) => !row.isActive)) {
        _showMessage('Choose at least one active service before going online.');
        return;
      }

      final position = await services.location.currentPosition();
      final availability = await services.availability.updateMine(
        isOnline: true,
        isAvailable: true,
        latitude: position.latitude,
        longitude: position.longitude,
        serviceRadiusKm: _radiusKm,
      );

      _applyAvailability(availability);
      messenger.showSnackBar(
        const SnackBar(content: Text('You are online. Location updated.')),
      );
    } on PartnerLocationException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: error.needsSettings
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: services.location.openSettings,
                )
              : null,
        ),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isChangingAvailability = false);
      }
    }
  }

  Future<void> _goOffline() async {
    if (_isChangingAvailability) {
      return;
    }

    final services = AppServicesScope.of(context);
    setState(() => _isChangingAvailability = true);
    try {
      final availability = await services.availability.updateMine(
        isOnline: false,
        isAvailable: false,
        serviceRadiusKm: _radiusKm,
      );
      _applyAvailability(availability);
      _showMessage('You are offline.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isChangingAvailability = false);
      }
    }
  }

  Future<void> _refreshOnlineLocation({required bool showErrors}) async {
    final services = AppServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final position = await services.location.currentPosition();
      final availability = await services.availability.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _applyAvailability(availability);
      if (showErrors) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Current location updated.')),
        );
      }
    } on PartnerLocationException catch (error) {
      if (showErrors) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on ApiException catch (error) {
      if (showErrors) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _saveRadius(double value) async {
    _radiusKm = value.roundToDouble();

    final availability = _availability;
    if (availability == null || !availability.isOnline) {
      setState(() {});
      return;
    }

    final services = AppServicesScope.of(context);
    setState(() => _isUpdatingRange = true);
    try {
      final updated = await services.availability.updateMine(
        serviceRadiusKm: _radiusKm,
      );
      _applyAvailability(updated);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingRange = false);
      }
    }
  }

  void _applyAvailability(PartnerAvailability availability) {
    if (!mounted) {
      return;
    }

    setState(() {
      _availability = availability;
      _radiusKm = availability.serviceRadiusKm ?? _radiusKm;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final partner = SessionScope.of(context).partner;

    if (partner == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      color: AppTheme.red,
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _PartnerHeader(partner: partner),
          const SizedBox(height: 18),
          _ApprovalCard(partner: partner),
          const SizedBox(height: 16),
          _AvailabilityCard(
            availability: _availability,
            isLoading: _isLoadingAvailability,
            isBusy: _isChangingAvailability,
            onGoOnline: () => _goOnline(partner),
            onGoOffline: _goOffline,
          ),
          const SizedBox(height: 16),
          _RadiusCard(
            radiusKm: _radiusKm,
            isUpdating: _isUpdatingRange,
            onChanged: (value) => setState(() => _radiusKm = value),
            onChangeEnd: _saveRadius,
          ),
          const SizedBox(height: 16),
          _TodaySummaryCard(
            dashboard: _dashboard,
            isLoading: _isLoadingDashboard,
            error: _dashboardError,
            onRetry: _loadDashboard,
          ),
          const SizedBox(height: 16),
          _EarningsCard(dashboard: _dashboard, isLoading: _isLoadingDashboard),
          const SizedBox(height: 16),
          _QuickAccessCard(
            activeJob: _dashboard?.activeJob,
            onOpenJobs: widget.onOpenJobs,
            onOpenProfile: widget.onOpenProfile,
          ),
          const SizedBox(height: 16),
          _RecentJobsCard(
            dashboard: _dashboard,
            isLoading: _isLoadingDashboard,
            onOpenJobs: widget.onOpenJobs,
          ),
          const SizedBox(height: 16),
          const _RulesCard(),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _PartnerHeader extends StatelessWidget {
  const _PartnerHeader({required this.partner});

  final Partner partner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: const BoxDecoration(
        color: AppTheme.red,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Row(
        children: [
          const WashbinLogo(size: 50, showShadow: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  partner.ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.partner});

  final Partner partner;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1B8A4B);

    return _Panel(
      child: Row(
        children: [
          _IconBadge(icon: Icons.verified_rounded, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.stage.label,
                  style: const TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'You can go online after selecting at least one service and sharing your current location.',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.availability,
    required this.isLoading,
    required this.isBusy,
    required this.onGoOnline,
    required this.onGoOffline,
  });

  final PartnerAvailability? availability;
  final bool isLoading;
  final bool isBusy;
  final VoidCallback onGoOnline;
  final VoidCallback onGoOffline;

  @override
  Widget build(BuildContext context) {
    final state = availability?.state ?? PartnerAvailabilityState.offline;
    final isOnline = state != PartnerAvailabilityState.offline;
    final accent = switch (state) {
      PartnerAvailabilityState.offline => AppTheme.red,
      PartnerAvailabilityState.available => const Color(0xFF1B8A4B),
      PartnerAvailabilityState.busy => const Color(0xFF9B5A00),
    };

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(
                icon: isOnline
                    ? Icons.wifi_tethering_rounded
                    : Icons.wifi_off_rounded,
                color: accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading
                          ? 'Checking availability...'
                          : 'You are ${state.label}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusText(state),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isLoading || isBusy
                ? null
                : isOnline
                ? onGoOffline
                : onGoOnline,
            icon: isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(isOnline ? Icons.power_settings_new : Icons.play_arrow),
            label: Text(isOnline ? 'Go Offline' : 'Go Online'),
          ),
        ],
      ),
    );
  }

  static String _statusText(PartnerAvailabilityState state) {
    return switch (state) {
      PartnerAvailabilityState.offline =>
        'Offline partners cannot receive job offers.',
      PartnerAvailabilityState.available =>
        'Available for jobs. Current location updated.',
      PartnerAvailabilityState.busy =>
        'Online but busy. You will not receive another job offer.',
    };
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.dashboard,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final PartnerDashboard? dashboard;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final today = dashboard?.today;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(icon: Icons.today_rounded, color: AppTheme.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dashboard?.asOf == null
                          ? 'Latest dashboard summary'
                          : 'Updated ${_timeLabel(dashboard!.asOf!)}',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading && dashboard == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null && dashboard == null)
            _InlineError(message: error!, onRetry: onRetry)
          else if (today == null || !dashboard!.hasAnyJobs)
            const _EmptyState(
              icon: Icons.work_history_outlined,
              title: 'No jobs yet',
              body: 'Your completed, upcoming, and cancelled jobs will appear here.',
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Completed',
                        value: '${today.completedJobs}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        label: 'Upcoming',
                        value: '${today.upcomingJobs}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Cancelled',
                        value: '${today.cancelledJobs}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        label: 'Earnings',
                        value: _moneyLabel(today.earnings),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.dashboard, required this.isLoading});

  final PartnerDashboard? dashboard;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final earnings = dashboard?.earnings;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _IconBadge(
                icon: Icons.currency_rupee_rounded,
                color: AppTheme.red,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Earnings',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading && earnings == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          else if (earnings == null || !earnings.hasAny)
            const _EmptyState(
              icon: Icons.savings_outlined,
              title: 'No earnings yet',
              body: 'Completed jobs with backend-confirmed prices will build this summary.',
            )
          else
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Today',
                    value: _moneyLabel(earnings.today),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'This Week',
                    value: _moneyLabel(earnings.week),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'This Month',
                    value: _moneyLabel(earnings.month),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.activeJob,
    required this.onOpenJobs,
    required this.onOpenProfile,
  });

  final JobBookingSummary? activeJob;
  final VoidCallback? onOpenJobs;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick access',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenJobs,
                icon: const Icon(Icons.assignment_turned_in_rounded),
                label: Text(activeJob == null ? 'Jobs' : 'Active Job'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenJobs,
                icon: const Icon(Icons.history_rounded),
                label: const Text('History'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenProfile,
                icon: const Icon(Icons.person_rounded),
                label: const Text('Profile'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentJobsCard extends StatelessWidget {
  const _RecentJobsCard({
    required this.dashboard,
    required this.isLoading,
    required this.onOpenJobs,
  });

  final PartnerDashboard? dashboard;
  final bool isLoading;
  final VoidCallback? onOpenJobs;

  @override
  Widget build(BuildContext context) {
    final rows = dashboard?.recentJobs ?? const <JobBookingSummary>[];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _IconBadge(icon: Icons.history_rounded, color: AppTheme.red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recent Jobs',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isLoading && rows.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          else if (rows.isEmpty)
            const _EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No recent jobs',
              body:
                  'Accepted, completed, and cancelled jobs will show up here.',
            )
          else
            for (final job in rows.take(4)) ...[
              _RecentJobRow(job: job),
              if (job != rows.take(4).last) const SizedBox(height: 12),
            ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenJobs,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open jobs'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentJobRow extends StatelessWidget {
  const _RecentJobRow({required this.job});

  final JobBookingSummary job;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_statusIcon(job.status), color: AppTheme.red, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.service.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${job.status.label} - ${job.customer.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          job.price == null ? '' : job.price!.displayLabel,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(
            color: AppTheme.red,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _IconBadge(icon: icon, color: AppTheme.red),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _RadiusCard extends StatelessWidget {
  const _RadiusCard({
    required this.radiusKm,
    required this.isUpdating,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double radiusKm;
  final bool isUpdating;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Icons.social_distance_rounded,
                color: AppTheme.red,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Operating range: ${radiusKm.round()} km',
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (isUpdating)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          Slider(
            value: radiusKm.clamp(1, 25),
            min: 1,
            max: 25,
            divisions: 24,
            label: '${radiusKm.round()} km',
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
          const Text(
            'Washbin uses this radius with your latest location when matching nearby jobs.',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Column(
        children: [
          _RuleRow(
            icon: Icons.block_rounded,
            label: 'Offline',
            value: 'Cannot receive jobs',
          ),
          SizedBox(height: 12),
          _RuleRow(
            icon: Icons.check_circle_rounded,
            label: 'Online + available',
            value: 'Can receive job offers',
          ),
          SizedBox(height: 12),
          _RuleRow(
            icon: Icons.pause_circle_filled_rounded,
            label: 'Online + busy',
            value: 'Cannot receive another job',
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.red, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: child,
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

IconData _statusIcon(JobBookingStatus status) => switch (status) {
  JobBookingStatus.completed => Icons.verified_rounded,
  JobBookingStatus.cancelled => Icons.cancel_rounded,
  JobBookingStatus.accepted ||
  JobBookingStatus.onTheWay ||
  JobBookingStatus.arrived ||
  JobBookingStatus.inProgress => Icons.assignment_turned_in_rounded,
  _ => Icons.work_rounded,
};

String _moneyLabel(double amount) {
  final text = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '₹$text';
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
