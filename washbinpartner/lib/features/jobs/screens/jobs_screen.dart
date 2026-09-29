import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:washbinpartner/app/app_services_scope.dart';
import 'package:washbinpartner/core/api/api_exception.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/features/jobs/domain/job_offer.dart';
import 'package:url_launcher/url_launcher.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  static const _historyPageSize = 30;

  final _offers = <JobOffer>[];
  final _completed = <JobBookingSummary>[];
  final _cancelled = <JobBookingSummary>[];
  final _otpController = TextEditingController();
  JobBookingSummary? _activeJob;
  String? _actingOnOfferId;
  bool _isLoading = true;
  bool _isLoadingHistory = false;
  bool _isLoadingMoreHistory = false;
  bool _isUpdatingJob = false;
  bool _hasMoreCompleted = true;
  bool _hasMoreCancelled = true;
  int _tab = 0;
  Timer? _expiryTicker;
  Timer? _liveRefreshTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadJobs());
    _expiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _removeExpiredOffers();
    });
    _liveRefreshTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_activeJob != null) {
        _loadJobs(showLoading: false, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _expiryTicker?.cancel();
    _liveRefreshTicker?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs({bool showLoading = true, bool silent = false}) async {
    if (_tab == 1) {
      return _loadHistory(JobBookingStatus.completed, showLoading: showLoading);
    }
    if (_tab == 2) {
      return _loadHistory(JobBookingStatus.cancelled, showLoading: showLoading);
    }

    final services = AppServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hadActiveJob = _activeJob != null;

    if (showLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final active = await services.jobExecution.getActive();
      final offers = active == null
          ? await services.jobOffers.getMine()
          : const <JobOffer>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _activeJob = active;
        if (active == null) {
          _offers
            ..clear()
            ..addAll(offers.where((offer) => offer.isOpen));
        } else {
          _offers.clear();
        }
      });

      if (!silent && hadActiveJob && active == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Active job is no longer available.')),
        );
      }
    } on ApiException catch (error) {
      if (!silent) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadHistory(
    JobBookingStatus status, {
    bool showLoading = true,
    bool append = false,
  }) async {
    final services = AppServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final target = status == JobBookingStatus.completed
        ? _completed
        : _cancelled;
    final skip = append ? target.length : 0;

    if (showLoading) {
      setState(() {
        if (append) {
          _isLoadingMoreHistory = true;
        } else {
          _isLoadingHistory = true;
        }
      });
    }

    try {
      final rows = await services.jobExecution.getHistory(
        status: status,
        limit: _historyPageSize,
        skip: skip,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        final target = status == JobBookingStatus.completed
            ? _completed
            : _cancelled;
        if (!append) {
          target.clear();
        }
        target.addAll(rows);
        if (status == JobBookingStatus.completed) {
          _hasMoreCompleted = rows.length == _historyPageSize;
        } else {
          _hasMoreCancelled = rows.length == _historyPageSize;
        }
      });
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _isLoadingHistory = false;
          _isLoadingMoreHistory = false;
        });
      }
    }
  }

  Future<void> _loadMoreHistory() {
    if (_isLoadingHistory || _isLoadingMoreHistory) {
      return Future.value();
    }
    if (_tab == 1 && _hasMoreCompleted) {
      return _loadHistory(JobBookingStatus.completed, append: true);
    }
    if (_tab == 2 && _hasMoreCancelled) {
      return _loadHistory(JobBookingStatus.cancelled, append: true);
    }
    return Future.value();
  }

  Future<void> _selectTab(int tab) async {
    if (_tab == tab) {
      return;
    }
    setState(() => _tab = tab);

    if (tab == 1 && _completed.isEmpty) {
      await _loadHistory(JobBookingStatus.completed);
    }
    if (tab == 2 && _cancelled.isEmpty) {
      await _loadHistory(JobBookingStatus.cancelled);
    }
  }

  Future<void> _accept(JobOffer offer) async {
    if (_activeJob != null || _actingOnOfferId != null) {
      return;
    }

    final services = AppServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _actingOnOfferId = offer.id);

    try {
      final accepted = await services.jobOffers.accept(offer.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _activeJob = accepted.booking;
        _offers.clear();
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Job accepted. You are now busy.')),
      );
    } on ApiException catch (error) {
      await _loadJobs(showLoading: false);
      messenger.showSnackBar(SnackBar(content: Text(_jobError(error))));
    } finally {
      if (mounted) {
        setState(() => _actingOnOfferId = null);
      }
    }
  }

  Future<void> _reject(JobOffer offer) async {
    if (_actingOnOfferId != null) {
      return;
    }

    final services = AppServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _actingOnOfferId = offer.id);

    try {
      await services.jobOffers.reject(offer.id);
      if (!mounted) {
        return;
      }
      setState(() => _offers.removeWhere((row) => row.id == offer.id));
      messenger.showSnackBar(
        const SnackBar(content: Text('Job rejected. You remain available.')),
      );
    } on ApiException catch (error) {
      await _loadJobs(showLoading: false);
      messenger.showSnackBar(SnackBar(content: Text(_jobError(error))));
    } finally {
      if (mounted) {
        setState(() => _actingOnOfferId = null);
      }
    }
  }

  Future<void> _advanceActiveJob(_JobAction action) async {
    final active = _activeJob;
    if (active == null || _isUpdatingJob) {
      return;
    }

    final services = AppServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isUpdatingJob = true);

    try {
      final updated = switch (action) {
        _JobAction.onTheWay => await services.jobExecution.markOnTheWay(
          active.id,
        ),
        _JobAction.arrived => await services.jobExecution.markArrived(
          active.id,
        ),
        _JobAction.start => await _startService(active.id),
        _JobAction.complete => await services.jobExecution.completeService(
          active.id,
        ),
      };

      if (!mounted) {
        return;
      }

      if (updated.status == JobBookingStatus.completed) {
        setState(() {
          _activeJob = null;
          _otpController.clear();
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Service completed. You are available again.'),
          ),
        );
        await _loadJobs(showLoading: false, silent: true);
      } else {
        setState(() => _activeJob = updated);
      }
    } on ApiException catch (error) {
      await _loadJobs(showLoading: false, silent: true);
      messenger.showSnackBar(SnackBar(content: Text(_jobError(error))));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingJob = false);
      }
    }
  }

  Future<JobBookingSummary> _startService(String bookingId) {
    final otp = _otpController.text.trim();
    final execution = AppServicesScope.of(context).jobExecution;

    if (otp.isEmpty) {
      return execution.startService(bookingId);
    }
    return execution.verifyStartOtp(bookingId: bookingId, otp: otp);
  }

  Future<void> _navigateToCustomer(JobBookingSummary booking) async {
    final address = booking.address;
    final messenger = ScaffoldMessenger.of(context);

    if (!address.hasCoordinates) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Customer location is not available.')),
      );
      return;
    }

    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${address.latitude},${address.longitude}',
    });

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: address.oneLine));
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open maps. Address copied.')),
        );
      }
    }
  }

  Future<void> _callCustomer(JobBookingSummary booking) async {
    final phone = booking.customer.phone;
    final messenger = ScaffoldMessenger.of(context);

    if (phone == null || phone.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Customer phone is not available.')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not open the dialler. Number copied.'),
          ),
        );
      }
    }
  }

  void _removeExpiredOffers() {
    if (!mounted || _offers.every((offer) => offer.isOpen)) {
      return;
    }

    setState(() => _offers.removeWhere((offer) => !offer.isOpen));
  }

  String _jobError(ApiException error) {
    final message = error.message;
    final lower = message.toLowerCase();
    if (lower.contains('expired') ||
        lower.contains('already') ||
        lower.contains('no longer available')) {
      return 'This job is no longer available.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.red,
      onRefresh: _loadJobs,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const _Header(),
          const SizedBox(height: 16),
          _JobTabs(selected: _tab, onSelected: _selectTab),
          const SizedBox(height: 16),
          if (_tab == 0 && _activeJob != null)
            _ActiveJobCard(
              booking: _activeJob!,
              otpController: _otpController,
              isUpdating: _isUpdatingJob,
              onAction: _advanceActiveJob,
              onNavigate: () => _navigateToCustomer(_activeJob!),
              onCall: () => _callCustomer(_activeJob!),
            )
          else if (_tab == 0 && _isLoading && _offers.isEmpty)
            const _LoadingCard()
          else if (_tab == 0 && _offers.isEmpty)
            const _EmptyOffersCard()
          else if (_tab == 0)
            for (final offer in _offers) ...[
              _OfferCard(
                offer: offer,
                isWorking: _actingOnOfferId == offer.id,
                onAccept: () => _accept(offer),
                onReject: () => _reject(offer),
              ),
              if (offer != _offers.last) const SizedBox(height: 14),
            ]
          else if (_isLoadingHistory)
            const _LoadingCard()
          else
            _HistoryList(
              rows: _tab == 1 ? _completed : _cancelled,
              emptyTitle: _tab == 1
                  ? 'No completed jobs yet'
                  : 'No cancelled jobs yet',
              hasMore: _tab == 1 ? _hasMoreCompleted : _hasMoreCancelled,
              isLoadingMore: _isLoadingMoreHistory,
              onOpen: _showJobDetails,
              onLoadMore: _loadMoreHistory,
            ),
        ],
      ),
    );
  }

  void _showJobDetails(JobBookingSummary booking) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) => _JobDetailsSheet(booking: booking),
    );
  }
}

enum _JobAction { onTheWay, arrived, start, complete }

class _JobTabs extends StatelessWidget {
  const _JobTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('Active')),
        ButtonSegment(value: 1, label: Text('Completed')),
        ButtonSegment(value: 2, label: Text('Cancelled')),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onSelected(selection.single),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _IconBadge(icon: Icons.work_rounded, color: AppTheme.red),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jobs',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Incoming requests and active service work.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.isWorking,
    required this.onAccept,
    required this.onReject,
  });

  final JobOffer offer;
  final bool isWorking;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final booking = offer.booking;
    final price = booking.price;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Icons.notifications_active_rounded,
                color: Color(0xFF1B8A4B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Job Request',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expires in ${_secondsLeft(offer)}s',
                      style: const TextStyle(
                        color: AppTheme.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.home_repair_service_rounded,
            label: 'Service',
            value: booking.service.name,
          ),
          _DetailRow(
            icon: Icons.route_rounded,
            label: 'Distance',
            value: offer.distanceLabel,
          ),
          _DetailRow(
            icon: Icons.place_rounded,
            label: 'Location',
            value: booking.address.areaLine.isEmpty
                ? booking.address.oneLine
                : booking.address.areaLine,
          ),
          _DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Scheduled',
            value: booking.scheduledLabel,
          ),
          if (price != null)
            _DetailRow(
              icon: Icons.currency_rupee_rounded,
              label: 'Estimated Earnings',
              value: price.displayLabel,
            ),
          if (booking.notes != null) ...[
            const SizedBox(height: 8),
            Text(
              booking.notes!,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isWorking ? null : onReject,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isWorking ? null : onAccept,
                  icon: isWorking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _secondsLeft(JobOffer offer) {
    final seconds = offer.expiresAt.difference(DateTime.now()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }
}

class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({
    required this.booking,
    required this.otpController,
    required this.isUpdating,
    required this.onAction,
    required this.onNavigate,
    required this.onCall,
  });

  final JobBookingSummary booking;
  final TextEditingController otpController;
  final bool isUpdating;
  final ValueChanged<_JobAction> onAction;
  final VoidCallback onNavigate;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final next = _nextAction(booking.status);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Icons.assignment_turned_in_rounded,
                color: Color(0xFF1B8A4B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active Job',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${booking.status.label}',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.home_repair_service_rounded,
            label: 'Service',
            value: booking.service.name,
          ),
          _DetailRow(
            icon: Icons.person_rounded,
            label: 'Customer',
            value: booking.customer.name,
          ),
          _DetailRow(
            icon: Icons.place_rounded,
            label: 'Address',
            value: booking.address.oneLine,
          ),
          _DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Scheduled',
            value: booking.scheduledLabel,
          ),
          _DetailRow(
            icon: Icons.confirmation_number_rounded,
            label: 'Booking ID',
            value: booking.reference,
          ),
          if (booking.notes != null)
            _DetailRow(
              icon: Icons.notes_rounded,
              label: 'Notes',
              value: booking.notes!,
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Navigate'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Call'),
                ),
              ),
            ],
          ),
          if (booking.status == JobBookingStatus.arrived) ...[
            const SizedBox(height: 12),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Customer OTP',
                prefixIcon: Icon(Icons.pin_rounded),
                counterText: '',
              ),
            ),
          ],
          if (next != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isUpdating ? null : () => onAction(next.action),
              icon: isUpdating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(next.icon),
              label: Text(next.label),
            ),
          ],
        ],
      ),
    );
  }

  _NextJobAction? _nextAction(JobBookingStatus status) => switch (status) {
    JobBookingStatus.accepted => const _NextJobAction(
      action: _JobAction.onTheWay,
      label: 'On The Way',
      icon: Icons.directions_bike_rounded,
    ),
    JobBookingStatus.onTheWay => const _NextJobAction(
      action: _JobAction.arrived,
      label: 'Arrived',
      icon: Icons.location_on_rounded,
    ),
    JobBookingStatus.arrived => const _NextJobAction(
      action: _JobAction.start,
      label: 'Start Service',
      icon: Icons.play_arrow_rounded,
    ),
    JobBookingStatus.inProgress => const _NextJobAction(
      action: _JobAction.complete,
      label: 'Complete Service',
      icon: Icons.task_alt_rounded,
    ),
    _ => null,
  };
}

class _NextJobAction {
  const _NextJobAction({
    required this.action,
    required this.label,
    required this.icon,
  });

  final _JobAction action;
  final String label;
  final IconData icon;
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.rows,
    required this.emptyTitle,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onOpen,
    required this.onLoadMore,
  });

  final List<JobBookingSummary> rows;
  final String emptyTitle;
  final bool hasMore;
  final bool isLoadingMore;
  final ValueChanged<JobBookingSummary> onOpen;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _Panel(
        child: Column(
          children: [
            const _IconBadge(icon: Icons.history_rounded, color: AppTheme.red),
            const SizedBox(height: 12),
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Finished and cancelled jobs will appear here.',
              textAlign: TextAlign.center,
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

    return Column(
      children: [
        for (final row in rows) ...[
          _HistoryCard(booking: row, onTap: () => onOpen(row)),
          if (row != rows.last) const SizedBox(height: 12),
        ],
        if (hasMore) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: isLoadingMore ? null : onLoadMore,
            icon: isLoadingMore
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(isLoadingMore ? 'Loading...' : 'Load more'),
          ),
        ],
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.booking, required this.onTap});

  final JobBookingSummary booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCancelled = booking.status == JobBookingStatus.cancelled;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBadge(
                  icon: isCancelled
                      ? Icons.cancel_rounded
                      : Icons.verified_rounded,
                  color: isCancelled ? AppTheme.red : const Color(0xFF1B8A4B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.service.name,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.customer.name,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Date',
              value: _dateLabel(booking.completedAt ?? booking.cancelledAt),
            ),
            _DetailRow(
              icon: Icons.place_rounded,
              label: 'Location',
              value: booking.address.areaLine.isEmpty
                  ? booking.address.oneLine
                  : booking.address.areaLine,
            ),
            _DetailRow(
              icon: Icons.info_rounded,
              label: 'Status',
              value: booking.status.label,
            ),
          ],
        ),
      ),
    );
  }
}

class _JobDetailsSheet extends StatelessWidget {
  const _JobDetailsSheet({required this.booking});

  final JobBookingSummary booking;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Job Details',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.confirmation_number_rounded,
            label: 'Booking ID',
            value: booking.reference,
          ),
          _DetailRow(
            icon: Icons.home_repair_service_rounded,
            label: 'Service',
            value: booking.service.name,
          ),
          _DetailRow(
            icon: Icons.person_rounded,
            label: 'Customer',
            value: booking.customer.name,
          ),
          _DetailRow(
            icon: Icons.place_rounded,
            label: 'Address',
            value: booking.address.oneLine,
          ),
          _DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Scheduled',
            value: booking.scheduledLabel,
          ),
          _DetailRow(
            icon: Icons.check_circle_rounded,
            label: 'Accepted',
            value: _dateLabel(booking.acceptedAt),
          ),
          _DetailRow(
            icon: Icons.play_circle_fill_rounded,
            label: 'Started',
            value: _dateLabel(booking.startedAt),
          ),
          _DetailRow(
            icon: Icons.task_alt_rounded,
            label: 'Completed',
            value: _dateLabel(booking.completedAt),
          ),
          _DetailRow(
            icon: Icons.info_rounded,
            label: 'Final',
            value: booking.status.label,
          ),
        ],
      ),
    );
  }
}

class _EmptyOffersCard extends StatelessWidget {
  const _EmptyOffersCard();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Column(
        children: [
          _IconBadge(icon: Icons.inbox_rounded, color: AppTheme.red),
          SizedBox(height: 12),
          Text(
            'No incoming job requests',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Stay online and available to receive new offers.',
            textAlign: TextAlign.center,
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.red, size: 20),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not available' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

String _dateLabel(DateTime? value) {
  if (value == null) {
    return 'Not available';
  }
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} $hour:$minute';
}
