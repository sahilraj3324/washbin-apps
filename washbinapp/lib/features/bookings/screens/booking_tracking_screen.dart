import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/async/async_controller.dart';
import 'package:washbinapp/core/async/async_state.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/core/widgets/app_error_view.dart';
import 'package:washbinapp/core/widgets/app_loading_indicator.dart';
import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/domain/booking_status.dart';
import 'package:washbinapp/features/bookings/domain/booking_time.dart';
import 'package:washbinapp/features/bookings/domain/booking_timeline.dart';
import 'package:washbinapp/features/bookings/widgets/booking_timeline_view.dart';
import 'package:washbinapp/features/bookings/widgets/booking_status_badge.dart';
import 'package:washbinapp/features/bookings/widgets/partner_panel.dart';
import 'package:url_launcher/url_launcher.dart';

/// Follows one booking from creation to completion.
///
/// Reads `GET /bookings/:id` on open and then on a timer, stopping as soon as
/// the status can no longer change on its own. The status the server reports
/// is the only source of truth: this screen never advances a stage itself.
class BookingTrackingScreen extends StatefulWidget {
  const BookingTrackingScreen({
    super.key,
    required this.bookingId,
    this.serviceName,
    this.initial,
  });

  final String bookingId;

  /// Known by the caller in most cases; a booking carries only a service id.
  final String? serviceName;

  /// Lets the screen paint immediately when the caller already has the
  /// booking, rather than opening on a spinner.
  final Booking? initial;

  @override
  State<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends State<BookingTrackingScreen>
    with WidgetsBindingObserver {
  AsyncController<Booking>? _booking;
  Timer? _poll;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    // Polling is paused while the app is backgrounded: a screen nobody is
    // looking at should not be making requests.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_booking != null) {
      return;
    }
    final bookings = AppServicesScope.of(context).bookings;
    final controller = AsyncController(
      () => bookings.getBooking(widget.bookingId),
      initialValue: widget.initial,
    )..addListener(_onBookingChanged);

    _booking = controller;
    // A booking handed in is already current; anything else needs fetching.
    widget.initial == null ? controller.load() : controller.refresh();
    _schedulePoll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _booking?.refresh();
      _schedulePoll();
    } else {
      _poll?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _booking
      ?..removeListener(_onBookingChanged)
      ..dispose();
    super.dispose();
  }

  void _onBookingChanged() {
    // A booking that has finished moving stops being polled, rather than
    // being asked the same question every few seconds forever.
    final booking = _booking?.state.valueOrNull;

    if (booking != null && !booking.status.isLive) {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _schedulePoll() {
    _poll?.cancel();

    final interval = AppServicesScope.of(context).trackingPollInterval;
    final booking = _booking?.state.valueOrNull;

    // Null disables polling outright, which is how tests run without a timer
    // firing under them.
    if (interval == null || (booking != null && !booking.status.isLive)) {
      return;
    }

    _poll = Timer.periodic(interval, (_) {
      final current = _booking;
      if (current == null || !mounted) {
        return;
      }
      if (current.state.valueOrNull?.status.isLive == false) {
        _poll?.cancel();
        return;
      }
      current.refresh();
    });
  }

  Future<void> _cancel(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: const Text(
          'We will stop looking for a partner. You can book again any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false) || !mounted) {
      return;
    }

    final bookings = AppServicesScope.of(context).bookings;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isCancelling = true);

    try {
      await bookings.cancel(booking.id);
    } on ApiException catch (error) {
      // The server decides. A 409 means the booking moved past the point
      // where cancelling is allowed while this screen was open.
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      await _booking?.refresh();
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);

    if (!await launchUrl(uri)) {
      if (!mounted) {
        return;
      }
      // No dialer, or the platform refused — the number is still useful.
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the dialler. Number copied.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _booking!;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: AppTheme.red,
        foregroundColor: Colors.white,
        title: Text(
          widget.serviceName ?? 'Your booking',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.red,
          onRefresh: controller.refresh,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => switch (controller.state) {
              AsyncLoading<Booking>() => const AppLoadingIndicator.fullScreen(
                label: 'Loading your booking',
              ),
              AsyncFailure<Booking>(:final error) => AppErrorView.fromException(
                error,
                onRetry: controller.load,
              ),
              AsyncData<Booking>(:final value) ||
              AsyncRefreshing<Booking>(:final value) => _Body(
                booking: value,
                isCancelling: _isCancelling,
                onCancel: () => _cancel(value),
                onCall: value.assignedPartner?.canCall ?? false
                    ? () => _call(value.assignedPartner!.phone!)
                    : null,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.booking,
    required this.isCancelling,
    required this.onCancel,
    required this.onCall,
  });

  final Booking booking;
  final bool isCancelling;
  final VoidCallback onCancel;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final status = booking.status;
    final otp = booking.liveStartOtp;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _StatusHeader(booking: booking),
        const SizedBox(height: 16),
        if (status == BookingStatus.noPartnerFound) ...[
          const _NoPartnerNote(),
          const SizedBox(height: 16),
        ],
        if (status == BookingStatus.cancelled) ...[
          _CancellationNote(booking: booking),
          const SizedBox(height: 16),
        ],
        if (otp != null && status == BookingStatus.arrived) ...[
          _StartOtp(code: otp),
          const SizedBox(height: 16),
        ],
        if (booking.hasPartner) ...[
          PartnerPanel(
            partner: booking.assignedPartner,
            etaMinutes: booking.etaMinutes,
            onCall: onCall,
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PROGRESS',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 16),
              BookingTimelineView(steps: BookingTimeline.of(booking)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Details(booking: booking),
        if (status.isCancellable) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: isCancelling ? null : onCancel,
            icon: isCancelling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.red,
                    ),
                  )
                : const Icon(Icons.close_rounded),
            label: Text(isCancelling ? 'Cancelling...' : 'Cancel booking'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.red,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppTheme.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final status = booking.status;
    final isSearching = status == BookingStatus.searchingPartner;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.red,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  status.display,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (isSearching)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            status.explanation,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Booking ID: ${booking.reference}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The code the partner quotes to start work, proving they reached the door.
class _StartOtp extends StatelessWidget {
  const _StartOtp({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.red, width: 1.6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Give this code to your partner',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'They need it to start the service.',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            code,
            style: const TextStyle(
              color: AppTheme.red,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// What is known about a cancellation.
///
/// The API records only when it happened — there is no reason field and no
/// record of who called it off — so the two lines below appear only if the
/// booking ever starts carrying them.
class _CancellationNote extends StatelessWidget {
  const _CancellationNote({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final at = booking.cancelledAt;
    final by = booking.cancelledByLabel;
    final reason = booking.cancellationReason;

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
          const Row(
            children: [
              Icon(Icons.cancel_rounded, color: AppTheme.muted, size: 18),
              SizedBox(width: 10),
              Text(
                'CANCELLED',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (at != null)
            _Line(label: 'Cancelled at', value: BookingTime.describe(at)),
          if (by != null) ...[
            const SizedBox(height: 10),
            _Line(label: 'Cancelled by', value: by),
          ],
          if (reason != null) ...[
            const SizedBox(height: 10),
            _Line(label: 'Reason', value: reason),
          ],
          if (at == null && by == null && reason == null)
            const Text(
              'This booking was cancelled.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _NoPartnerNote extends StatelessWidget {
  const _NoPartnerNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFB45309).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFB45309).withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_off_rounded, color: Color(0xFFB45309), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nobody was free this time. Cancel this booking and try again, '
              'or wait — we keep looking when partners come online.',
              style: TextStyle(
                color: AppTheme.ink,
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

class _Details extends StatelessWidget {
  const _Details({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final scheduledAt = booking.scheduledAt;
    final price = booking.price;
    final snapshot = booking.addressSnapshot;

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
              const Text(
                'DETAILS',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: BookingStatusBadge(status: booking.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Line(
            label: 'When',
            value: scheduledAt != null
                ? BookingTime.describe(scheduledAt)
                : booking.createdAt != null
                ? 'Booked ${BookingTime.describe(booking.createdAt!)}'
                : 'As soon as a partner is free',
          ),
          if (snapshot != null) ...[
            const SizedBox(height: 10),
            _Line(label: 'Where', value: snapshot.oneLine),
          ],
          if (price != null) ...[
            const SizedBox(height: 10),
            _Line(
              label: price.isEstimate ? 'Estimated price' : 'Price',
              value: price.displayLabel,
            ),
          ],
          if (booking.notes != null) ...[
            const SizedBox(height: 10),
            _Line(label: 'Notes', value: booking.notes!),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
