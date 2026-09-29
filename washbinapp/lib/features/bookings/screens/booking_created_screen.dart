import 'package:flutter/material.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/domain/booking_status.dart';
import 'package:washbinapp/features/bookings/domain/booking_time.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';

/// Confirmation that the booking exists, and what is happening to it.
///
/// The status shown is the one the server answered with — an instant booking
/// has already been through matching by the time this renders, so it may say
/// "searching", "partner found", or that nobody was free.
class BookingCreatedScreen extends StatelessWidget {
  const BookingCreatedScreen({
    super.key,
    required this.booking,
    required this.service,
  });

  final Booking booking;
  final Service service;

  @override
  Widget build(BuildContext context) {
    final scheduledAt = booking.scheduledAt;
    final price = booking.price;

    return PopScope(
      // Back would land on the summary screen, whose Confirm button would
      // create a second booking. The only way on is Done.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.canvas,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppTheme.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.red,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Booking created',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                service.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              _StatusCard(status: booking.status),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.line),
                ),
                child: Column(
                  children: [
                    _Line(
                      label: 'When',
                      value: scheduledAt == null
                          ? 'As soon as a partner is free'
                          : BookingTime.describe(scheduledAt),
                    ),
                    if (booking.addressSnapshot != null) ...[
                      const SizedBox(height: 12),
                      _Line(
                        label: 'Where',
                        value: booking.addressSnapshot!.oneLine,
                      ),
                    ],
                    if (price != null) ...[
                      const SizedBox(height: 12),
                      _Line(
                        label: price.isEstimate ? 'Estimated price' : 'Price',
                        value: price.displayLabel,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  AppRouter.bookingTracking(
                    bookingId: booking.id,
                    serviceName: service.name,
                    initial: booking,
                  ),
                ),
                icon: const Icon(Icons.timeline_rounded),
                label: const Text('Track booking'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Done'),
              ),
              const SizedBox(height: 10),
              const Text(
                'You can follow this booking from the Bookings tab.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.red,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(_icon, color: Colors.white, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.display,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status.explanation,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData get _icon => switch (status) {
    BookingStatus.pending => Icons.event_available_rounded,
    BookingStatus.searchingPartner => Icons.person_search_rounded,
    BookingStatus.noPartnerFound => Icons.person_off_rounded,
    BookingStatus.cancelled => Icons.cancel_rounded,
    _ => Icons.check_circle_rounded,
  };
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
